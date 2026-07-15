[CmdletBinding()]
param(
    # Skip the interactive confirmation prompt (intended for automation).
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module (Join-Path -Path $PSScriptRoot -ChildPath "TtydCommon.psm1") -Force

$FabricApiBaseUrl = "https://api.fabric.microsoft.com/v1"

function Get-AzdJsonValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $raw = Get-AzdEnvValue -Name $Name -Optional
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $null
    }

    return $raw | ConvertFrom-Json
}

function Get-FabricAccessToken {
    $token = az account get-access-token --resource "https://api.fabric.microsoft.com" --query accessToken --output tsv 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($token)) {
        throw "Failed to acquire a Microsoft Fabric access token. Ensure you are signed in with 'az login'."
    }

    return $token.Trim()
}

function Invoke-FabricDelete {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourcePath,
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,
        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    $uri = "$FabricApiBaseUrl/$ResourcePath"
    try {
        Invoke-RestMethod -Method Delete -Uri $uri -Headers @{ Authorization = "Bearer $AccessToken" } -ErrorAction Stop | Out-Null
        Write-Host "[destroy] Deleted $Description."
    }
    catch {
        $status = $null
        if ($_.Exception.PSObject.Properties.Name -contains "Response" -and $null -ne $_.Exception.Response) {
            $status = [int]$_.Exception.Response.StatusCode
        }

        if ($status -eq 404) {
            Write-Host "[destroy] $Description already gone (404)."
        }
        else {
            Write-Warning "[destroy] Failed to delete ${Description}: $($_.Exception.Message)"
        }
    }
}

try {
    # -----------------------------------------------
    # Resolve environment + read identifiers from azd
    # -----------------------------------------------
    $envName = $env:AZURE_ENV_NAME
    if ([string]::IsNullOrWhiteSpace($envName)) {
        $envName = azd env get-value AZURE_ENV_NAME 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($envName)) {
            throw "Could not determine the azd environment. Run through azd, or select one first with 'azd env select <name>'."
        }
        $envName = $envName.Trim()
    }

    $subscriptionId = Get-AzdEnvValue -Name "AZURE_SUBSCRIPTION_ID"
    $resourceGroupName = Get-AzdEnvValue -Name "resource_group_name"
    $subnetIds = Get-AzdJsonValue -Name "subnet_ids"
    $fabricGatewayId = Get-AzdEnvValue -Name "fabric_gateway_id" -Optional
    $fabricGatewayName = Get-AzdEnvValue -Name "fabric_gateway_name" -Optional
    $fabricWorkspaceIds = Get-AzdJsonValue -Name "fabric_workspace_ids"
    $groupObjectId = Get-AzdEnvValue -Name "ttyd_group_object_id" -Optional
    $groupName = Get-AzdEnvValue -Name "ttyd_group_name" -Optional
    $userObjectIds = Get-AzdJsonValue -Name "ttyd_user_object_ids"

    # -----------------------------------------------
    # Confirmation (destructive, irreversible)
    # -----------------------------------------------
    if (-not $Force) {
        $workspaceCount = if ($null -ne $fabricWorkspaceIds) { @($fabricWorkspaceIds.PSObject.Properties).Count } else { 0 }
        $userCount = if ($null -ne $userObjectIds) { @($userObjectIds).Count } else { 0 }

        Write-Host ""
        Write-Host "This will PERMANENTLY DELETE the '$envName' environment:" -ForegroundColor Yellow
        Write-Host "  - Fabric workspaces : $workspaceCount"
        Write-Host "  - Fabric gateway    : $fabricGatewayName"
        Write-Host "  - Resource group    : $resourceGroupName"
        Write-Host "                        (SQL MI, App Service, storage, Fabric capacity, VNet, NSGs, route tables)"
        Write-Host "  - Entra group       : $groupName"
        Write-Host "  - Entra users       : $userCount"
        Write-Host ""
        $confirmation = Read-Host "Type the environment name '$envName' to confirm"
        if ($confirmation -ne $envName) {
            throw "Confirmation did not match. Aborting without changes."
        }
    }

    # -----------------------------------------------
    # Target the correct subscription
    # -----------------------------------------------
    az account set --subscription $subscriptionId --only-show-errors
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to select subscription '$subscriptionId'. Run 'az login' and try again."
    }

    # -----------------------------------------------
    # 1) Fabric workspaces (tenant objects, not in the RG)
    # -----------------------------------------------
    $needFabricToken = ($null -ne $fabricWorkspaceIds -and @($fabricWorkspaceIds.PSObject.Properties).Count -gt 0) `
        -or (-not [string]::IsNullOrWhiteSpace($fabricGatewayId))

    $fabricToken = $null
    if ($needFabricToken) {
        $fabricToken = Get-FabricAccessToken
    }

    if ($null -ne $fabricWorkspaceIds) {
        foreach ($workspace in $fabricWorkspaceIds.PSObject.Properties) {
            $workspaceId = $workspace.Value
            if (-not [string]::IsNullOrWhiteSpace($workspaceId)) {
                Invoke-FabricDelete -ResourcePath "workspaces/$workspaceId" -AccessToken $fabricToken `
                    -Description "Fabric workspace '$($workspace.Name)' ($workspaceId)"
            }
        }
    }

    # -----------------------------------------------
    # 2) Fabric VNet gateway - MANDATORY before the VNet can be removed.
    #    The gateway holds a Power Platform vnet access link into the
    #    fabric_vnet subnet that otherwise blocks VNet/RG deletion.
    # -----------------------------------------------
    if (-not [string]::IsNullOrWhiteSpace($fabricGatewayId)) {
        Invoke-FabricDelete -ResourcePath "gateways/$fabricGatewayId" -AccessToken $fabricToken `
            -Description "Fabric VNet gateway '$fabricGatewayName' ($fabricGatewayId)"
    }

    # -----------------------------------------------
    # 3) Disassociate NSGs and route tables from every subnet -
    #    MANDATORY before the VNet can be removed.
    # -----------------------------------------------
    if ($null -ne $subnetIds) {
        foreach ($subnet in $subnetIds.PSObject.Properties) {
            $subnetId = $subnet.Value
            if ([string]::IsNullOrWhiteSpace($subnetId)) {
                continue
            }

            az network vnet subnet update --ids $subnetId --nsg "" --route-table "" --only-show-errors | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[destroy] Disassociated NSG/route table from subnet '$($subnet.Name)'."
            }
            else {
                Write-Warning "[destroy] Could not disassociate NSG/route table from subnet '$($subnet.Name)' (continuing; RG deletion will clean it up)."
            }
        }
    }

    # -----------------------------------------------
    # 4) Delete the resource group. ARM resolves internal ordering and
    #    removes the VNet, SQL MI, App Service, storage, Fabric capacity,
    #    NSGs and route tables. SQL MI deletion can take a long time.
    # -----------------------------------------------
    $rgExists = az group exists --name $resourceGroupName --subscription $subscriptionId --output tsv 2>$null
    if ($rgExists -eq "true") {
        Write-Host "[destroy] Deleting resource group '$resourceGroupName' (this can take a while, especially SQL MI)..."
        az group delete --name $resourceGroupName --subscription $subscriptionId --yes --only-show-errors
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to delete resource group '$resourceGroupName'."
        }
        Write-Host "[destroy] Resource group '$resourceGroupName' deleted."
    }
    else {
        Write-Host "[destroy] Resource group '$resourceGroupName' not found. Skipping."
    }

    # -----------------------------------------------
    # 5) Entra objects (tenant scope) - group, then users.
    # -----------------------------------------------
    if (-not [string]::IsNullOrWhiteSpace($groupObjectId)) {
        az ad group delete --group $groupObjectId --only-show-errors
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[destroy] Deleted Entra group '$groupName' ($groupObjectId)."
        }
        else {
            Write-Warning "[destroy] Could not delete Entra group '$groupName' ($groupObjectId) (may already be gone)."
        }
    }

    if ($null -ne $userObjectIds) {
        foreach ($userObjectId in $userObjectIds) {
            if ([string]::IsNullOrWhiteSpace($userObjectId)) {
                continue
            }

            az ad user delete --id $userObjectId --only-show-errors
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[destroy] Deleted Entra user $userObjectId."
            }
            else {
                Write-Warning "[destroy] Could not delete Entra user $userObjectId (may already be gone)."
            }
        }
    }

    Write-Host ""
    Write-Host "[destroy] Environment '$envName' teardown completed." -ForegroundColor Green
    Write-Host "[destroy] Note: the local azd environment under '.azure/$envName' and its terraform state were left in place. Remove them manually if desired."
    exit 0
}
catch {
    Write-Error "[destroy] Failed: $($_.Exception.Message)"
    exit 1
}
