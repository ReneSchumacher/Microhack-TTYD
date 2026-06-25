# ─────────────────────────────────────────────
# NSG: nsg-sqlhackmi  (ManagedInstance subnet)
# Required management rules for Azure SQL Managed Instance
# Ref: https://learn.microsoft.com/en-us/azure/azure-sql/managed-instance/connectivity-architecture-overview
# ─────────────────────────────────────────────
resource "azurerm_network_security_group" "sql_mi" {
  name                = "nsg-sqlhackmi"
  location            = var.location
  resource_group_name = var.resource_group_name

  lifecycle {
    ignore_changes = [
      security_rule
    ]
  }

  tags = merge(var.tags, {
    environment = var.env_name
  })
}




resource "azurerm_subnet_network_security_group_association" "managed_instance" {
  subnet_id                 = azurerm_subnet.managed_instance.id
  network_security_group_id = azurerm_network_security_group.sql_mi.id

  depends_on = [azurerm_network_security_group.sql_mi]
}



# ─────────────────────────────────────────────
# NSG: sqlhack-shared-bastion-nsg  (AzureBastionSubnet)
# Required rules for Azure Bastion
# Ref: https://learn.microsoft.com/en-us/azure/bastion/bastion-nsg
# ─────────────────────────────────────────────
resource "azurerm_network_security_group" "bastion" {
  name                = "sqlhack-shared-bastion-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  # ── Inbound ──────────────────────────────────

  security_rule {
    name                       = "allow-bastion-inbound-https-internet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-bastion-inbound-gateway-manager"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-bastion-inbound-azure-lb"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-bastion-inbound-host-comm"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["8080", "5701"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "deny-bastion-inbound-all"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # ── Outbound ─────────────────────────────────

  security_rule {
    name                       = "allow-bastion-outbound-ssh-rdp"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "3389"]
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "allow-bastion-outbound-azure-cloud"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureCloud"
  }

  security_rule {
    name                       = "allow-bastion-outbound-host-comm"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["8080", "5701"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "allow-bastion-outbound-session-info"
    priority                   = 130
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }

  tags = merge(var.tags, {
    environment = var.env_name
  })
}

# ─────────────────────────────────────────────
# NSG: sqlhack-shared-mgmt-nsg  (Management subnet)
# ─────────────────────────────────────────────
resource "azurerm_network_security_group" "management" {
  name                = "sqlhack-shared-mgmt-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "allow-mgmt-inbound-vnet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "allow-mgmt-inbound-bastion"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "3389"]
    source_address_prefix      = "10.0.4.0/24"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "deny-mgmt-inbound-all"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = merge(var.tags, {
    environment = var.env_name
  })
}

# ─────────────────────────────────────────────
# NSG: sqlhack-shared-jump-nsg  (TeamJumpbox subnet)
# ─────────────────────────────────────────────
resource "azurerm_network_security_group" "team_jumpbox" {
  name                = "sqlhack-shared-jump-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "allow-jump-inbound-bastion"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "3389"]
    source_address_prefix      = "10.0.4.0/24"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-jump-inbound-vnet"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "deny-jump-inbound-all"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = merge(var.tags, {
    environment = var.env_name
  })
}

# ─────────────────────────────────────────────
# NSG: SQLHACK-appservice-nsg  (snet-appservice subnet)
# ─────────────────────────────────────────────
resource "azurerm_network_security_group" "appservice" {
  name                = "SQLHACK-appservice-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "allow-appservice-inbound-vnet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "allow-appservice-inbound-alb"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "deny-appservice-inbound-all"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = merge(var.tags, {
    environment = var.env_name
  })
}

# ─────────────────────────────────────────────
# NSG: sqlhack-shared-fabric-nsg  (fabric_vnet subnet)
# ─────────────────────────────────────────────
resource "azurerm_network_security_group" "fabric" {
  name                = "sqlhack-shared-fabric-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "allow-fabric-inbound-vnet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "deny-fabric-inbound-all"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = merge(var.tags, {
    environment = var.env_name
  })
}

# ─────────────────────────────────────────────
# NSG: SQLHACK-streaming-nsg  (StreamingVnet subnet)
# ─────────────────────────────────────────────
resource "azurerm_network_security_group" "streaming" {
  name                = "SQLHACK-streaming-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "allow-streaming-inbound-vnet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "deny-streaming-inbound-all"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = merge(var.tags, {
    environment = var.env_name
  })
}

# ─────────────────────────────────────────────
# NSG → Subnet associations
# ─────────────────────────────────────────────

resource "azurerm_subnet_network_security_group_association" "management" {
  subnet_id                 = azurerm_subnet.management.id
  network_security_group_id = azurerm_network_security_group.management.id
}

resource "azurerm_subnet_network_security_group_association" "team_jumpbox" {
  subnet_id                 = azurerm_subnet.team_jumpbox.id
  network_security_group_id = azurerm_network_security_group.team_jumpbox.id
}

resource "azurerm_subnet_network_security_group_association" "bastion" {
  subnet_id                 = azurerm_subnet.bastion.id
  network_security_group_id = azurerm_network_security_group.bastion.id
}

resource "azurerm_subnet_network_security_group_association" "appservice" {
  subnet_id                 = azurerm_subnet.appservice.id
  network_security_group_id = azurerm_network_security_group.appservice.id
}

resource "azurerm_subnet_network_security_group_association" "fabric" {
  subnet_id                 = azurerm_subnet.fabric.id
  network_security_group_id = azurerm_network_security_group.fabric.id
}

resource "azurerm_subnet_network_security_group_association" "streaming" {
  subnet_id                 = azurerm_subnet.streaming.id
  network_security_group_id = azurerm_network_security_group.streaming.id
}

