Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module (Join-Path -Path $PSScriptRoot -ChildPath "TtydCommon.psm1") -Force

function Check-TablesExist {
	param(
		[Parameter(Mandatory = $true)]
		[string]$ServerInstance,
		[Parameter(Mandatory = $true)]
		[string]$Database,
		[Parameter(Mandatory = $true)]
		[string]$Username,
		[Parameter(Mandatory = $true)]
		[string]$Password
	)

	$query = "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE'"
	$tableCount = Invoke-Sqlcmd `
		-ServerInstance $ServerInstance `
		-Database $Database `
		-Username $Username `
		-Password $Password `
		-Query $query `
		-ConnectionTimeout 15 `
		-QueryTimeout 30 `
		-ErrorAction Stop

	return $tableCount."Column1" -gt 0
}

try {
	$repoRoot = Split-Path -Path $PSScriptRoot -Parent
	$databaseName = "TailspinToys_Demo_Final"
	$schemaFilePath = Join-Path -Path $repoRoot -ChildPath "sql/TailspinToys_Demo_Final_withdata.sql"

	if (-not (Test-Path -Path $schemaFilePath)) {
		throw "Schema file not found at '$schemaFilePath'."
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

	Write-Host "[postprovision] Applying schema to database '$databaseName' on '$serverInstance'."

	if (-not (Get-Module -ListAvailable -Name SqlServer)) {
		Write-Host "[postprovision] Installing SqlServer PowerShell module for Invoke-Sqlcmd."
		Install-Module -Name SqlServer -Scope CurrentUser -Repository PSGallery -Force -AllowClobber
	}
	Import-Module SqlServer -ErrorAction Stop

	$connectivityReady = $false
	for ($attempt = 1; $attempt -le 20; $attempt++) {
		try {
			Invoke-Sqlcmd `
				-ServerInstance $serverInstance `
				-Database $databaseName `
				-Username $sqlLogin `
				-Password $sqlPassword `
				-Query "SELECT 1" `
				-ConnectionTimeout 15 `
				-QueryTimeout 30 `
				-ErrorAction Stop | Out-Null

			$connectivityReady = $true
			break
		}
		catch {
			Write-Host "[postprovision] SQL not ready yet (attempt $attempt/20). Waiting 30s."
			Start-Sleep -Seconds 30
		}
	}

	if (-not $connectivityReady) {
		throw "Timed out waiting for SQL connectivity to '$serverInstance'."
	}

	Write-Host "[postprovision] Checking if database already has tables."
	$tablesExist = Check-TablesExist `
		-ServerInstance $serverInstance `
		-Database $databaseName `
		-Username $sqlLogin `
		-Password $sqlPassword

	if ($tablesExist) {
		Write-Host "[postprovision] Database already contains tables. Schema deployment skipped."
		exit 0
	}

	Write-Host "[postprovision] Applying schema to database '$databaseName' on '$serverInstance'."
	Invoke-Sqlcmd `
		-ServerInstance $serverInstance `
		-Database $databaseName `
		-Username $sqlLogin `
		-Password $sqlPassword `
		-InputFile $schemaFilePath `
		-ConnectionTimeout 30 `
		-QueryTimeout 1200 `
		-ErrorAction Stop | Out-Null

	Write-Host "[postprovision] Schema deployment completed successfully."
	exit 0
}
catch {
	Write-Error "[postprovision] Failed: $($_.Exception.Message)"
	exit 1
}
