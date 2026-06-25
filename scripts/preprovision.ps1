Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Entra Global Administrator directory role template id (well-known, constant).
$GlobalAdminRoleTemplateId = "62e90394-69f5-4237-9190-012177145e10"

# Resource providers that must be registered on the subscription.
$RequiredResourceProviders = @(
    "Microsoft.Fabric",
    "Microsoft.PowerPlatform"
)

function Assert-ModuleAvailable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if (-not (Get-Module -ListAvailable -Name $Name)) {
        throw "Required PowerShell module '$Name' is not installed. Install it with: Install-Module $Name -Scope CurrentUser"
    }

    Import-Module $Name -ErrorAction Stop
}

function Get-DotEnvValues {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path)) {
        throw "Missing .env file at '$Path'."
    }

    $values = @{}
    foreach ($line in Get-Content -Path $Path) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        if ($line.TrimStart().StartsWith("#")) {
            continue
        }

        $pair = $line -split "=", 2
        if ($pair.Count -ne 2) {
            continue
        }

        $key = $pair[0].Trim()
        $value = $pair[1].Trim()

        if ($value.StartsWith('"') -and $value.EndsWith('"')) {
            $value = $value.Substring(1, $value.Length - 2)
        }

        # azd writes escaped values in .env for special characters.
        $value = $value -replace '\\\\', '\\' -replace '\\"', '"' -replace '\\!', '!'
        $values[$key] = $value
    }

    return $values
}

function Get-EnvSettings {
    $repoRoot = Split-Path -Path $PSScriptRoot -Parent

    $envName = $env:AZURE_ENV_NAME
    if ([string]::IsNullOrWhiteSpace($envName)) {
        # Fall back to discovery when not invoked through azd (e.g. manual run).
        $envFolders = @(Get-ChildItem -Path (Join-Path -Path $repoRoot -ChildPath ".azure") -Directory -ErrorAction SilentlyContinue |
            Where-Object { Test-Path -Path (Join-Path -Path $_.FullName -ChildPath ".env") })

        if ($envFolders.Count -eq 0) {
            throw "Could not locate an azd environment. Set AZURE_ENV_NAME or run through azd."
        }

        if ($envFolders.Count -gt 1) {
            throw "Multiple azd environments found under '.azure'. Set AZURE_ENV_NAME to select one."
        }

        $envName = $envFolders[0].Name
    }

    $envFilePath = Join-Path -Path $repoRoot -ChildPath ".azure/$envName/.env"
    $envValues = Get-DotEnvValues -Path $envFilePath

    $subscriptionId = $envValues["AZURE_SUBSCRIPTION_ID"]
    if ([string]::IsNullOrWhiteSpace($subscriptionId)) {
        throw "AZURE_SUBSCRIPTION_ID is missing in '$envFilePath'."
    }

    # Tenant is optional in the .env; used to scope a silent sign-in when required.
    $tenant = $envValues["TENANT_DOMAIN"]

    return [pscustomobject]@{
        EnvName        = $envName
        EnvFilePath    = $envFilePath
        SubscriptionId = $subscriptionId
        Tenant         = $tenant
    }
}

function Get-AzureContextInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,
        [string]$Tenant
    )

    $context = Get-AzContext -ErrorAction SilentlyContinue
    if ($null -eq $context -or $null -eq $context.Account) {
        Write-Host "No Azure PowerShell session found. Signing in silently..."
        $connectParams = @{
            Subscription  = $SubscriptionId
            WarningAction = "SilentlyContinue"
            ErrorAction   = "Stop"
        }
        if (-not [string]::IsNullOrWhiteSpace($Tenant)) {
            $connectParams["Tenant"] = $Tenant
        }
        Connect-AzAccount @connectParams | Out-Null
    }

    # Ensure the active context targets the subscription from the .env file.
    $setParams = @{
        Subscription = $SubscriptionId
        ErrorAction  = "Stop"
    }
    if (-not [string]::IsNullOrWhiteSpace($Tenant)) {
        $setParams["Tenant"] = $Tenant
    }
    $context = Set-AzContext @setParams

    if ($null -eq $context.Subscription) {
        throw "Could not select subscription '$SubscriptionId'. Verify the signed-in account has access."
    }

    return $context
}

function Connect-Graph {
    param(
        [string]$Tenant
    )

    $mgContext = Get-MgContext -ErrorAction SilentlyContinue
    if ($null -eq $mgContext) {
        Write-Host "No Microsoft Graph session found. Signing in silently..."
        $connectParams = @{
            Scopes      = "Directory.Read.All"
            NoWelcome   = $true
            ErrorAction = "Stop"
        }
        if (-not [string]::IsNullOrWhiteSpace($Tenant)) {
            $connectParams["TenantId"] = $Tenant
        }
        Connect-MgGraph @connectParams | Out-Null
        $mgContext = Get-MgContext -ErrorAction Stop
    }

    return $mgContext
}

function Test-GlobalAdministrator {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserPrincipalName
    )

    $user = Get-MgUser -UserId $UserPrincipalName -ErrorAction Stop
    $memberships = Get-MgUserMemberOf -UserId $user.Id -All -ErrorAction Stop

    foreach ($membership in $memberships) {
        if ($membership.AdditionalProperties["@odata.type"] -ne "#microsoft.graph.directoryRole") {
            continue
        }

        if ($membership.AdditionalProperties["roleTemplateId"] -eq $GlobalAdminRoleTemplateId) {
            return $true
        }
    }

    return $false
}

function Test-SubscriptionOwner {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,
        [Parameter(Mandatory = $true)]
        [string]$ObjectId
    )

    $scope = "/subscriptions/$SubscriptionId"
    # -SignedInUser is unavailable in older Az.Resources; query by the user's object id instead.
    $assignments = Get-AzRoleAssignment -ObjectId $ObjectId -Scope $scope -ErrorAction Stop

    foreach ($assignment in $assignments) {
        if ($assignment.RoleDefinitionName -eq "Owner") {
            return $true
        }
    }

    return $false
}

function Test-ResourceProviderRegistered {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProviderNamespace
    )

    # Get-AzResourceProvider returns one entry per resource type; collapse to a single namespace state.
    $providers = @(Get-AzResourceProvider -ProviderNamespace $ProviderNamespace -ErrorAction SilentlyContinue)
    if ($providers.Count -eq 0) {
        return $false
    }

    $state = $providers[0].RegistrationState
    return ($state -eq "Registered")
}

$results = New-Object System.Collections.Generic.List[object]

function Add-CheckResult {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [bool]$Passed,
        [string]$Detail = ""
    )

    $results.Add([pscustomobject]@{
            Check  = $Name
            Status = if ($Passed) { "PASS" } else { "FAIL" }
            Passed = $Passed
            Detail = $Detail
        })
}

Write-Host "Verifying deployment prerequisites..." -ForegroundColor Cyan

# Ensure required modules are present before any checks run.
Assert-ModuleAvailable -Name "Az.Accounts"
Assert-ModuleAvailable -Name "Az.Resources"
Assert-ModuleAvailable -Name "Microsoft.Graph.Authentication"
Assert-ModuleAvailable -Name "Microsoft.Graph.Users"

$envSettings = Get-EnvSettings
$subscriptionId = $envSettings.SubscriptionId
$tenant = $envSettings.Tenant

Write-Host "Environment  : $($envSettings.EnvName) ($($envSettings.EnvFilePath))"
if (-not [string]::IsNullOrWhiteSpace($tenant)) {
    Write-Host "Tenant       : $tenant"
}

$azureContext = Get-AzureContextInfo -SubscriptionId $subscriptionId -Tenant $tenant
$signedInUser = $azureContext.Account.Id

Write-Host "Subscription : $($azureContext.Subscription.Name) ($($azureContext.Subscription.Id))"
Write-Host "Signed-in as : $signedInUser"

# Check 1: Entra Global Administrator.
try {
    Connect-Graph -Tenant $tenant | Out-Null
    $isGlobalAdmin = Test-GlobalAdministrator -UserPrincipalName $signedInUser
    Add-CheckResult -Name "Entra role 'Global Administrator'" -Passed $isGlobalAdmin `
        -Detail $(if ($isGlobalAdmin) { "Role is assigned." } else { "Role is not assigned to $signedInUser." })
}
catch {
    Add-CheckResult -Name "Entra role 'Global Administrator'" -Passed $false -Detail "Check failed: $($_.Exception.Message)"
}

# Check 2: Owner on the subscription.
try {
    $signedInUserId = (Get-AzADUser -SignedIn -ErrorAction Stop).Id
    if ([string]::IsNullOrWhiteSpace($signedInUserId)) {
        throw "Could not resolve the object id for the signed-in user '$signedInUser'."
    }
    $isOwner = Test-SubscriptionOwner -SubscriptionId $subscriptionId -ObjectId $signedInUserId
    Add-CheckResult -Name "Azure role 'Owner' on subscription" -Passed $isOwner `
        -Detail $(if ($isOwner) { "Owner assignment found on $subscriptionId." } else { "No Owner assignment found on $subscriptionId." })
}
catch {
    Add-CheckResult -Name "Azure role 'Owner' on subscription" -Passed $false -Detail "Check failed: $($_.Exception.Message)"
}

# Check 3: Required resource providers are registered.
foreach ($provider in $RequiredResourceProviders) {
    try {
        $isRegistered = Test-ResourceProviderRegistered -ProviderNamespace $provider
        Add-CheckResult -Name "Resource provider '$provider' registered" -Passed $isRegistered `
            -Detail $(if ($isRegistered) { "RegistrationState is Registered." } else { "Not registered. Run: Register-AzResourceProvider -ProviderNamespace $provider" })
    }
    catch {
        Add-CheckResult -Name "Resource provider '$provider' registered" -Passed $false -Detail "Check failed: $($_.Exception.Message)"
    }
}

Write-Host ""
Write-Host "Prerequisite check summary:" -ForegroundColor Cyan
$results | Format-Table -Property Check, Status, Detail -AutoSize | Out-String | Write-Host

$failed = @($results | Where-Object { -not $_.Passed })
if ($failed.Count -gt 0) {
    throw "$($failed.Count) prerequisite check(s) failed. Resolve the items marked FAIL above and retry."
}

Write-Host "All prerequisite checks passed." -ForegroundColor Green
