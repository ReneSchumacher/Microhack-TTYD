Set-StrictMode -Version Latest

<#
.SYNOPSIS
    Reads a value from the active azd environment.
.DESCRIPTION
    Delegates to `azd env get-value` so that azd handles all quoting and
    escape-character decoding. This avoids the fragile manual parsing of the
    .env file that previously lived in each script.
.PARAMETER Name
    The environment variable name to read (e.g. SQL_PASSWORD).
.PARAMETER Optional
    When set, returns $null instead of throwing if the value is missing.
#>
function Get-AzdEnvValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [switch]$Optional
    )

    $value = azd env get-value $Name 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($value)) {
        if ($Optional) {
            return $null
        }
        throw "Could not read '$Name' from the azd environment. Run through azd (or 'azd env select <name>')."
    }

    return $value.Trim()
}

<#
.SYNOPSIS
    Reads a named output value from a terraform state file.
#>
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

<#
.SYNOPSIS
    Reads the SQL Managed Instance FQDN output from a terraform state file.
#>
function Get-TfStateManagedInstanceFqdn {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return Get-TfStateOutput -Path $Path -OutputName 'sql_managed_instance_fqdn'
}

Export-ModuleMember -Function Get-AzdEnvValue, Get-TfStateOutput, Get-TfStateManagedInstanceFqdn
