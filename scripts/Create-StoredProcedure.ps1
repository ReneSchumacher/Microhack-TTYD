Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module (Join-Path -Path $PSScriptRoot -ChildPath "TtydCommon.psm1") -Force

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

    $tfStatePath = Join-Path -Path $repoRoot -ChildPath ".azure/$envName/infra/terraform.tfstate"

    $sqlLogin = Get-AzdEnvValue -Name "SQL_ADMIN_LOGIN"
    $sqlPassword = Get-AzdEnvValue -Name "SQL_PASSWORD"

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
