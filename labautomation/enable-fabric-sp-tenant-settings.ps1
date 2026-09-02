<#
.SYNOPSIS
One-time, admin-run helper that enables the Fabric tenant settings the platform service
principal needs, instead of clicking through the Fabric admin portal.
.DESCRIPTION
Enables both:
  - "Service principals can call Fabric public APIs"
  - "Service principals can create workspaces, connections, and deployment pipelines"
scoped to the given Entra security group (the group that contains the platform service
principal). Must be run by a user with the Fabric administrator (or Global administrator)
role — the Fabric tenant-settings API rejects calls from service principals for this
purpose, which is exactly the gap this script exists to bridge for the admin.
.PARAMETER SecurityGroupObjectId
Object ID of the Entra security group that contains the platform service principal.
.PARAMETER TenantId
Optional Entra tenant ID to sign in against. Defaults to the current az CLI context.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$SecurityGroupObjectId,

    [Parameter(Mandatory = $false)]
    [string]$TenantId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$FabricApi = 'https://api.fabric.microsoft.com/v1'
# Titles as shown in the Fabric admin portal; the underlying setting names are looked up dynamically
# below because they aren't guaranteed to stay stable across Fabric releases.
$TargetSettingTitles = @(
    'Service principals can call Fabric public APIs',
    'Service principals can create workspaces, connections, and deployment pipelines'
)

function Write-EnableTrace {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host "[enable-fabric-sp][trace] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
}

function Get-EnabledSecurityGroups {
    # ConvertFrom-Json omits absent JSON properties entirely; under Set-StrictMode that makes
    # direct property access throw instead of returning $null.
    param([Parameter(Mandatory = $true)][object]$Setting)
    $prop = $Setting.PSObject.Properties['enabledSecurityGroups']
    if (-not $prop -or -not $prop.Value) { return @() }
    return @($prop.Value)
}

function Invoke-FabricApi {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('GET', 'POST')][string]$Method,
        [Parameter(Mandatory = $true)][string]$Path,
        [object]$Body
    )
    $url = "$FabricApi/$($Path.TrimStart('/'))"
    $azArgs = @('rest', '--method', $Method, '--url', $url, '--resource', 'https://api.fabric.microsoft.com')
    $bodyFile = $null
    if ($Body) {
        # az.cmd mangles inline --body JSON quoting on Windows; a @file body avoids that entirely.
        $bodyFile = [System.IO.Path]::GetTempFileName()
        ($Body | ConvertTo-Json -Depth 10) | Set-Content -Path $bodyFile -Encoding utf8NoBOM
        $azArgs += @('--headers', 'Content-Type=application/json', '--body', "@$bodyFile")
    }
    try {
        $raw = az @azArgs 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Fabric API $Method $Path failed: $raw" }
    }
    finally {
        if ($bodyFile) { Remove-Item -Path $bodyFile -Force -ErrorAction SilentlyContinue }
    }
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    return ($raw | ConvertFrom-Json)
}

Write-Host ''
Write-Host 'This script must run as a user with the Fabric administrator (or Global administrator)'
Write-Host 'role. Sign in as that admin now, not as the platform deployment service principal.'
Write-Host ''

$account = az account show 2>$null | ConvertFrom-Json
if (-not $account -or ($TenantId -and $account.tenantId -ne $TenantId)) {
    if ($TenantId) { az login --tenant $TenantId | Out-Null } else { az login | Out-Null }
}

$context = az account show | ConvertFrom-Json
Write-EnableTrace "Signed in as $($context.user.name) (tenant $($context.tenantId))."

Write-EnableTrace 'Resolving security group display name via Microsoft Graph...'
$group = (az rest --method GET --url "https://graph.microsoft.com/v1.0/groups/$SecurityGroupObjectId`?`$select=id,displayName" --resource 'https://graph.microsoft.com' | ConvertFrom-Json)
Write-EnableTrace "Target security group: '$($group.displayName)' ($($group.id))."

Write-EnableTrace 'Listing current Fabric tenant settings...'
$allSettings = (Invoke-FabricApi -Method GET -Path 'admin/tenantsettings').tenantSettings

foreach ($title in $TargetSettingTitles) {
    $setting = $allSettings | Where-Object { $_.title -eq $title } | Select-Object -First 1
    if (-not $setting) {
        Write-Warning "Could not find a tenant setting titled '$title'. Skipping; enable it manually in the Fabric admin portal."
        continue
    }

    $currentGroups = Get-EnabledSecurityGroups -Setting $setting
    if (-not $setting.enabled) {
        Write-EnableTrace "'$title' is currently disabled."
    }
    elseif ($currentGroups) {
        Write-EnableTrace "'$title' is enabled for: $(($currentGroups | ForEach-Object { $_.name }) -join ', ')."
    }
    else {
        Write-EnableTrace "'$title' is enabled but has no security groups configured."
    }

    if ($setting.enabled -and ($currentGroups | Where-Object { $_.graphId -eq $group.id })) {
        Write-EnableTrace "'$title' is already enabled for '$($group.displayName)'. Nothing to do."
        continue
    }

    Write-EnableTrace "Enabling '$title' ($($setting.settingName)) for '$($group.displayName)'..."
    $existingGroups = @($currentGroups | Where-Object { $_.graphId -ne $group.id })
    $body = @{
        enabled                   = $true
        canSpecifySecurityGroups  = $true
        enabledSecurityGroups     = @($existingGroups + @{ graphId = $group.id; name = $group.displayName })
    }
    Invoke-FabricApi -Method POST -Path "admin/tenantsettings/$($setting.settingName)/update" -Body $body | Out-Null
    Write-EnableTrace "'$title' enabled."
}

Write-Host ''
Write-Host '[enable-fabric-sp] Done. Re-run the shared deployment hook; the platform service principal'
Write-Host 'should now be able to call Fabric APIs and create workspaces.'
