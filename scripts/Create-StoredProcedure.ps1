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

try {
    $repoRoot = Split-Path -Path $PSScriptRoot -Parent
    $jobsSqlPath = Join-Path -Path $repoRoot -ChildPath "sql/StoredProcedure.sql"

    if (-not (Test-Path -Path $jobsSqlPath)) {
        throw "StoredProcedure.sql not found at '$jobsSqlPath'."
    }

    $envName = $env:AZURE_ENV_NAME
    if ([string]::IsNullOrWhiteSpace($envName)) {
        throw "AZURE_ENV_NAME is not set. Run through azd so environment variables are available."
    }

    $envFilePath = Join-Path -Path $repoRoot -ChildPath ".azure/$envName/.env"
    $tfStatePath = Join-Path -Path $repoRoot -ChildPath ".azure/$envName/infra/terraform.tfstate"

    $envValues = Get-DotEnvValues -Path $envFilePath
    $sqlLogin = $envValues["SQL_ADMIN_LOGIN"]
    $sqlPassword = $envValues["SQL_PASSWORD"]

    if ([string]::IsNullOrWhiteSpace($sqlLogin)) {
        throw "SQL_ADMIN_LOGIN is missing in '$envFilePath'."
    }

    if ([string]::IsNullOrWhiteSpace($sqlPassword)) {
        throw "SQL_PASSWORD is missing in '$envFilePath'."
    }

    $serverFqdn = Get-TfStateManagedInstanceFqdn -Path $tfStatePath
    $publicServerFqdn = $serverFqdn -replace '^[^.]+\.', '$0public.'
    if ($publicServerFqdn -eq $serverFqdn) {
        throw "Unable to build SQL MI public endpoint FQDN from '$serverFqdn'."
    }
    $serverInstance = "$publicServerFqdn,3342"

    Write-Host "[execute-jobs] Reading StoredProcedure.sql from '$jobsSqlPath'."

    if (-not (Get-Module -ListAvailable -Name SqlServer)) {
        Write-Host "[execute-jobs] Installing SqlServer PowerShell module for Invoke-Sqlcmd."
        Install-Module -Name SqlServer -Scope CurrentUser -Repository PSGallery -Force -AllowClobber
    }
    Import-Module SqlServer -ErrorAction Stop

    Write-Host "[execute-jobs] Checking whether stored procedure 'dbo.usp_PurchaseSpaceRanger' already exists in 'TailspinToys_Demo_Final'."
    $procExists = Invoke-Sqlcmd `
        -ServerInstance $serverInstance `
        -Database "TailspinToys_Demo_Final" `
        -Username $sqlLogin `
        -Password $sqlPassword `
        -Query "SELECT CASE WHEN OBJECT_ID('dbo.usp_PurchaseSpaceRanger', 'P') IS NOT NULL THEN 1 ELSE 0 END AS ProcExists;" `
        -ConnectionTimeout 30 `
        -QueryTimeout 0 `
        -ErrorAction Stop

    if ($procExists.ProcExists -eq 1) {
        Write-Host "[execute-jobs] Stored procedure 'dbo.usp_PurchaseSpaceRanger' already exists. Nothing to do."
        exit 0
    }

    Write-Host "[execute-jobs] Connecting to SQL MI at '$serverInstance' and executing StoredProcedure.sql against master database."
    try {
        Invoke-Sqlcmd `
            -ServerInstance $serverInstance `
            -Database master `
            -Username $sqlLogin `
            -Password $sqlPassword `
            -InputFile $jobsSqlPath `
            -ConnectionTimeout 30 `
            -QueryTimeout 0 `
            -ErrorAction Stop
        Write-Host "[execute-jobs] StoredProcedure.sql executed successfully."
    }
    catch {
        Write-Error "[execute-jobs] Failed to execute StoredProcedure.sql: $($_.Exception.Message)"
        throw
    }

    Write-Host "[execute-jobs] Jobs execution completed successfully."
    exit 0
}
catch {
    Write-Error "[execute-jobs] Failed: $($_.Exception.Message)"
    exit 1
}
