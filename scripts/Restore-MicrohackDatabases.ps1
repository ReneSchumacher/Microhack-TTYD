Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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

function Get-TfStateManagedInstanceFqdn {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path)) {
        throw "Missing terraform state at '$Path'."
    }

    $json = Get-Content -Path $Path -Raw | ConvertFrom-Json
    $fqdn = $json.outputs.sql_managed_instance_fqdn.value
    if ([string]::IsNullOrWhiteSpace($fqdn)) {
        throw "Could not find outputs.sql_managed_instance_fqdn.value in '$Path'."
    }

    return $fqdn
}

function Get-TfStateOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$OutputName
    )

    if (-not (Test-Path -Path $Path)) {
        throw "Missing terraform state at '$Path'."
    }

    $json = Get-Content -Path $Path -Raw | ConvertFrom-Json
    $value = $json.outputs.$OutputName.value
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Could not find outputs.$OutputName.value in '$Path'."
    }

    return $value
}

function New-BlobSasUrl {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AccountName,
        [Parameter(Mandatory = $true)]
        [string]$ContainerName,
        [Parameter(Mandatory = $true)]
        [string]$AccountKey,
        [int]$ExpiryHours = 2
    )

    $expiry = (Get-Date).ToUniversalTime().AddHours($ExpiryHours).ToString("yyyy-MM-ddTHH:mmZ")
    $sasToken = az storage container generate-sas `
        --account-name $AccountName `
        --name $ContainerName `
        --account-key $AccountKey `
        --permissions rl `
        --https-only `
        --expiry $expiry `
        --output tsv 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to generate container SAS token for '$ContainerName': $sasToken"
    }

    return $sasToken
}

function Get-UserDatabaseNames {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prefix,
        [Parameter(Mandatory = $true)]
        [int]$Count
    )

    return 1..$Count | ForEach-Object {
        "{0}{1:D3}" -f $Prefix, $_
    }
}

function Get-TenantDomain {
    param(
        [Parameter(Mandatory = $true)]
        [string]$EnvFilePath,
        [string]$ParameterName = "TENANT_DOMAIN"
    )

    if (-not (Test-Path -Path $EnvFilePath)) {
        throw "Missing .env file at '$EnvFilePath'."
    }

    foreach ($line in Get-Content -Path $EnvFilePath) {
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

        if ($key -eq $ParameterName) {
            return $value
        }
    }

    throw "$ParameterName is missing in '$EnvFilePath'."
}

function Add-UserToDatabase {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServerInstance,
        [Parameter(Mandatory = $true)]
        [string]$SqlLogin,
        [Parameter(Mandatory = $true)]
        [string]$SqlPassword,
        [Parameter(Mandatory = $true)]
        [string]$DatabaseName,
        [Parameter(Mandatory = $true)]
        [string]$AzureAdUserPrincipalName
    )

    $loginName = "[$AzureAdUserPrincipalName]"
    
    # Create the login if it doesn't exist
    $createLoginQuery = @"
USE [master];
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'$AzureAdUserPrincipalName')
    CREATE LOGIN $loginName FROM EXTERNAL PROVIDER;
"@

    try {
        Invoke-Sqlcmd `
            -ServerInstance $ServerInstance `
            -Database master `
            -Username $SqlLogin `
            -Password $SqlPassword `
            -Query $createLoginQuery `
            -ConnectionTimeout 30 `
            -QueryTimeout 30 `
            -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Error "[setup-shop-database] Failed to create login for ${AzureAdUserPrincipalName}: $($_.Exception.Message)"
        throw
    }

    # Create the user and grant db_owner role
    $createUserQuery = @"
USE [$DatabaseName];
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'$AzureAdUserPrincipalName')
    CREATE USER $loginName FROM LOGIN $loginName;
ALTER ROLE [db_owner] ADD MEMBER $loginName;
"@

    try {
        Invoke-Sqlcmd `
            -ServerInstance $ServerInstance `
            -Database $DatabaseName `
            -Username $SqlLogin `
            -Password $SqlPassword `
            -Query $createUserQuery `
            -ConnectionTimeout 30 `
            -QueryTimeout 30 `
            -ErrorAction Stop | Out-Null
        Write-Host "[setup-shop-database] Added user ${AzureAdUserPrincipalName} to database ${DatabaseName} with db_owner role."
    }
    catch {
        Write-Error "[setup-shop-database] Failed to add user ${AzureAdUserPrincipalName} to database ${DatabaseName}: $($_.Exception.Message)"
        throw
    }
}

function Test-DatabaseExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServerInstance,
        [Parameter(Mandatory = $true)]
        [string]$SqlLogin,
        [Parameter(Mandatory = $true)]
        [string]$SqlPassword,
        [Parameter(Mandatory = $true)]
        [string]$DatabaseName
    )

    $query = @"
SELECT COUNT(*) AS DbCount FROM sys.databases WHERE name = N'$DatabaseName'
"@

    try {
        $result = Invoke-Sqlcmd `
            -ServerInstance $ServerInstance `
            -Database master `
            -Username $SqlLogin `
            -Password $SqlPassword `
            -Query $query `
            -ConnectionTimeout 30 `
            -QueryTimeout 30 `
            -ErrorAction Stop

        return $result.DbCount -gt 0
    }
    catch {
        Write-Error "[setup-shop-database] Failed to check if ${DatabaseName} exists: $($_.Exception.Message)"
        throw
    }
}

function Invoke-DatabaseRestore {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServerInstance,
        [Parameter(Mandatory = $true)]
        [string]$SqlLogin,
        [Parameter(Mandatory = $true)]
        [string]$SqlPassword,
        [Parameter(Mandatory = $true)]
        [string]$DatabaseName,
        [Parameter(Mandatory = $true)]
        [string]$BackupUrl
    )

    # Check if database already exists
    if (Test-DatabaseExists -ServerInstance $ServerInstance -SqlLogin $SqlLogin -SqlPassword $SqlPassword -DatabaseName $DatabaseName) {
        Write-Host "[setup-shop-database] Database ${DatabaseName} already exists. Skipping restore."
        return
    }

    $query = @"
USE [master];
RESTORE DATABASE [$DatabaseName]
FROM URL = N'$BackupUrl';
"@

    Write-Host "[setup-shop-database] Restoring $DatabaseName on '$ServerInstance'."
    try {
        Invoke-Sqlcmd `
            -ServerInstance $ServerInstance `
            -Database master `
            -Username $SqlLogin `
            -Password $SqlPassword `
            -Query $query `
            -ConnectionTimeout 30 `
            -QueryTimeout 0 `
            -ErrorAction Stop
        Write-Host "[setup-shop-database] $DatabaseName restored successfully."
    }
    catch {
        Write-Error "[setup-shop-database] Failed to restore ${DatabaseName}: $($_.Exception.Message)"
        throw
    }
}

try {
    $repoRoot = Split-Path -Path $PSScriptRoot -Parent

    $tailspinToysBlobName = "tailspintoys_before_launch.bak"
    $tailspinToysFeedbackBlobName = "tailspintoysfeedback_before_launch.bak"

    $envName = $env:AZURE_ENV_NAME
    if ([string]::IsNullOrWhiteSpace($envName)) {
        throw "AZURE_ENV_NAME is not set. Run through azd so environment variables are available."
    }

    $envFilePath = Join-Path -Path $repoRoot -ChildPath ".azure/$envName/.env"
    $tfStatePath = Join-Path -Path $repoRoot -ChildPath ".azure/$envName/infra/terraform.tfstate"

    $envValues = Get-DotEnvValues -Path $envFilePath
    $sqlLogin = $envValues["SQL_ADMIN_LOGIN"]
    $sqlPassword = $envValues["SQL_PASSWORD"]
    $userDatabaseCountRaw = $envValues["TAILSPIN_TOYS_USER_DATABASE_COUNT"]

    if ([string]::IsNullOrWhiteSpace($sqlLogin)) {
        throw "SQL_ADMIN_LOGIN is missing in '$envFilePath'."
    }

    if ([string]::IsNullOrWhiteSpace($sqlPassword)) {
        throw "SQL_PASSWORD is missing in '$envFilePath'."
    }

    if ([string]::IsNullOrWhiteSpace($userDatabaseCountRaw)) {
        throw "TAILSPIN_TOYS_USER_DATABASE_COUNT is missing in '$envFilePath'."
    }

    $userDatabaseCount = 0
    if (-not [int]::TryParse($userDatabaseCountRaw, [ref]$userDatabaseCount) -or $userDatabaseCount -lt 1) {
        throw "TAILSPIN_TOYS_USER_DATABASE_COUNT must be a positive integer. Current value: '$userDatabaseCountRaw'."
    }

    $serverFqdn = Get-TfStateManagedInstanceFqdn -Path $tfStatePath
    $publicServerFqdn = $serverFqdn -replace '^[^.]+\.', '$0public.'
    if ($publicServerFqdn -eq $serverFqdn) {
        throw "Unable to build SQL MI public endpoint FQDN from '$serverFqdn'."
    }
    $serverInstance = "$publicServerFqdn,3342"

    # --- Resolve storage account details from Terraform state ---
    $storageAccountName = Get-TfStateOutput -Path $tfStatePath -OutputName "backup_storage_account_name"
    $storageContainerName = Get-TfStateOutput -Path $tfStatePath -OutputName "backup_storage_container_name"
    $resourceGroupName = Get-TfStateOutput -Path $tfStatePath -OutputName "resource_group_name"

    Write-Host "[setup-shop-database] Retrieving storage account key for '$storageAccountName'."
    $storageAccountKey = az storage account keys list `
        --resource-group $resourceGroupName `
        --account-name $storageAccountName `
        --query "[0].value" `
        --output tsv 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to retrieve storage account key for '$storageAccountName': $storageAccountKey"
    }

    Write-Host "[setup-shop-database] Generating container SAS token for backup restores."
    $containerSasToken = New-BlobSasUrl `
        -AccountName $storageAccountName `
        -ContainerName $storageContainerName `
        -AccountKey $storageAccountKey

    $tailspinToysBackupUrl = "https://$storageAccountName.blob.core.windows.net/$storageContainerName/${tailspinToysBlobName}"
    $tailspinToysFeedbackBackupUrl = "https://$storageAccountName.blob.core.windows.net/$storageContainerName/${tailspinToysFeedbackBlobName}"

    if (-not (Get-Module -ListAvailable -Name SqlServer)) {
        Write-Host "[setup-shop-database] Installing SqlServer PowerShell module for Invoke-Sqlcmd."
        Install-Module -Name SqlServer -Scope CurrentUser -Repository PSGallery -Force -AllowClobber
    }
    Import-Module SqlServer -ErrorAction Stop

    # --- Create SQL credential for the storage container ---
    $credentialName = "https://$storageAccountName.blob.core.windows.net/$storageContainerName"
    $credentialIdentifier = "[$credentialName]"

    Write-Host "[setup-shop-database] Creating SQL credential for blob storage access."
    $createCredentialQuery = @"
USE [master];
IF EXISTS (SELECT 1 FROM sys.credentials WHERE name = N'$credentialName')
    DROP CREDENTIAL $credentialIdentifier;
CREATE CREDENTIAL $credentialIdentifier
WITH IDENTITY = 'Shared Access Signature',
SECRET = '$containerSasToken';
"@

    try {
        Invoke-Sqlcmd `
            -ServerInstance $serverInstance `
            -Database master `
            -Username $sqlLogin `
            -Password $sqlPassword `
            -Query $createCredentialQuery `
            -ConnectionTimeout 30 `
            -QueryTimeout 30 `
            -ErrorAction Stop | Out-Null
        Write-Host "[setup-shop-database] SQL credential created successfully."
    }
    catch {
        Write-Error "[setup-shop-database] Failed to create SQL credential: $($_.Exception.Message)"
        throw
    }

    Invoke-DatabaseRestore `
        -ServerInstance $serverInstance `
        -SqlLogin $sqlLogin `
        -SqlPassword $sqlPassword `
        -DatabaseName "TailspinToysFeedback_Demo_Final" `
        -BackupUrl $tailspinToysFeedbackBackupUrl

    Invoke-DatabaseRestore `
        -ServerInstance $serverInstance `
        -SqlLogin $sqlLogin `
        -SqlPassword $sqlPassword `
        -DatabaseName "TailspinToysFeedback_Demo_Mirrored" `
        -BackupUrl $tailspinToysFeedbackBackupUrl

    foreach ($databaseName in Get-UserDatabaseNames -Prefix "TailspinToysFeedback_User" -Count $userDatabaseCount) {
        Invoke-DatabaseRestore `
            -ServerInstance $serverInstance `
            -SqlLogin $sqlLogin `
            -SqlPassword $sqlPassword `
            -DatabaseName $databaseName `
            -BackupUrl $tailspinToysFeedbackBackupUrl
    }

    Invoke-DatabaseRestore `
        -ServerInstance $serverInstance `
        -SqlLogin $sqlLogin `
        -SqlPassword $sqlPassword `
        -DatabaseName "TailspinToys_Demo_Final" `
        -BackupUrl $tailspinToysBackupUrl

    Invoke-DatabaseRestore `
        -ServerInstance $serverInstance `
        -SqlLogin $sqlLogin `
        -SqlPassword $sqlPassword `
        -DatabaseName "TailspinToys_Demo_Mirroring" `
        -BackupUrl $tailspinToysBackupUrl

    foreach ($databaseName in Get-UserDatabaseNames -Prefix "TailspinToys_User" -Count $userDatabaseCount) {
        Invoke-DatabaseRestore `
            -ServerInstance $serverInstance `
            -SqlLogin $sqlLogin `
            -SqlPassword $sqlPassword `
            -DatabaseName $databaseName `
            -BackupUrl $tailspinToysBackupUrl
    }

    # --- Add test users to their corresponding databases with db_owner role ---
    Write-Host "[setup-shop-database] Adding ttyd test users to their databases with db_owner role."

    $ttydUpns = (Get-Content -Path $tfStatePath -Raw | ConvertFrom-Json).outputs.ttyd_user_principal_names.value
    if ($null -eq $ttydUpns -or $ttydUpns.Count -lt $userDatabaseCount) {
        throw "Could not read outputs.ttyd_user_principal_names.value (expected at least $userDatabaseCount entries) from '$tfStatePath'."
    }

    for ($i = 1; $i -le $userDatabaseCount; $i++) {
        $userIndex = "{0:D3}" -f $i
        $userPrincipalName = $ttydUpns | Where-Object { $_ -match "^ttyd${userIndex}[_@]" } | Select-Object -First 1
        if ([string]::IsNullOrWhiteSpace($userPrincipalName)) {
            throw "No user principal name matching 'ttyd${userIndex}' found in terraform state output ttyd_user_principal_names."
        }

        # Add user to TailspinToys_UserNNN database
        $tailspinToysDb = "TailspinToys_User${userIndex}"
        Add-UserToDatabase `
            -ServerInstance $serverInstance `
            -SqlLogin $sqlLogin `
            -SqlPassword $sqlPassword `
            -DatabaseName $tailspinToysDb `
            -AzureAdUserPrincipalName $userPrincipalName

        # Add user to TailspinToysFeedback_UserNNN database
        $tailspinToysFeedbackDb = "TailspinToysFeedback_User${userIndex}"
        Add-UserToDatabase `
            -ServerInstance $serverInstance `
            -SqlLogin $sqlLogin `
            -SqlPassword $sqlPassword `
            -DatabaseName $tailspinToysFeedbackDb `
            -AzureAdUserPrincipalName $userPrincipalName
    }

    Write-Host "[setup-shop-database] All test users added to databases with db_owner role."
    Write-Host "[setup-shop-database] All databases restored successfully."
    exit 0
}
catch {
    Write-Error "[setup-shop-database] Failed: $($_.Exception.Message)"
    exit 1
}
