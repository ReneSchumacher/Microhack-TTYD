# ─────────────────────────────────────────────
# Virtual Network
# ─────────────────────────────────────────────
resource "azurerm_virtual_network" "this" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.address_space

  tags = merge(var.tags, {
    environment = var.env_name
  })
}

# ─────────────────────────────────────────────
# Subnets
# ─────────────────────────────────────────────

# GatewaySubnet — no delegation, no NSG, no route table (reserved name for VPN/ER gateways)
resource "azurerm_subnet" "gateway" {
  name                            = "GatewaySubnet"
  resource_group_name             = var.resource_group_name
  virtual_network_name            = azurerm_virtual_network.this.name
  address_prefixes                = ["10.0.0.0/24"]
  default_outbound_access_enabled = false
}

# ManagedInstance — SQL MI delegation + NSG + route table
resource "azurerm_subnet" "managed_instance" {
  name                            = "ManagedInstance"
  resource_group_name             = var.resource_group_name
  virtual_network_name            = azurerm_virtual_network.this.name
  address_prefixes                = ["10.0.1.0/24"]
  default_outbound_access_enabled = false

  delegation {
    name = "sql-mi-delegation"
    service_delegation {
      name = "Microsoft.Sql/managedInstances"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action",
      ]
    }
  }
}

# Management
resource "azurerm_subnet" "management" {
  name                            = "Management"
  resource_group_name             = var.resource_group_name
  virtual_network_name            = azurerm_virtual_network.this.name
  address_prefixes                = ["10.0.2.0/24"]
  default_outbound_access_enabled = false
}

# TeamJumpbox
resource "azurerm_subnet" "team_jumpbox" {
  name                            = "TeamJumpbox"
  resource_group_name             = var.resource_group_name
  virtual_network_name            = azurerm_virtual_network.this.name
  address_prefixes                = ["10.0.3.0/24"]
  default_outbound_access_enabled = false
}

# AzureBastionSubnet — name must be exactly "AzureBastionSubnet"
resource "azurerm_subnet" "bastion" {
  name                            = "AzureBastionSubnet"
  resource_group_name             = var.resource_group_name
  virtual_network_name            = azurerm_virtual_network.this.name
  address_prefixes                = ["10.0.4.0/24"]
  default_outbound_access_enabled = false
}

# snet-appservice — App Service VNet integration delegation
resource "azurerm_subnet" "appservice" {
  name                            = "snet-appservice"
  resource_group_name             = var.resource_group_name
  virtual_network_name            = azurerm_virtual_network.this.name
  address_prefixes                = ["10.0.5.0/24"]
  default_outbound_access_enabled = false

  delegation {
    name = "appservice-delegation"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action",
      ]
    }
  }
}

# fabric_vnet
# NOTE: Microsoft Fabric delegation (Microsoft.PowerBI/privatelinkServicesForPowerBI or
# Microsoft.Fabric/*) is not supported by azurerm provider 3.x. Apply delegation through
# the Azure portal or via az cli after provisioning if required.
resource "azurerm_subnet" "fabric" {
  name                            = "fabric_vnet"
  resource_group_name             = var.resource_group_name
  virtual_network_name            = azurerm_virtual_network.this.name
  address_prefixes                = ["10.0.6.0/24"]
  default_outbound_access_enabled = false
  delegation {
    name = "powerplatform-delegation"
    service_delegation {
      name = "Microsoft.PowerPlatform/vnetaccesslinks"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }

}

# StreamingVnet
# NOTE: Microsoft.StreamAnalytics/clusters delegation is not in azurerm provider 3.x
# allowed list. Apply delegation through the Azure portal or az cli after provisioning.
resource "azurerm_subnet" "streaming" {
  name                            = "StreamingVnet"
  resource_group_name             = var.resource_group_name
  virtual_network_name            = azurerm_virtual_network.this.name
  address_prefixes                = ["10.0.7.0/24"]
  default_outbound_access_enabled = false
}

# ─────────────────────────────────────────────
# NSG → Subnet associations
# ─────────────────────────────────────────────
# NSG associations are now created by the network_security module
# to ensure they are deployed AFTER the managed instance is ready.
