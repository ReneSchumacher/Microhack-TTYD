output "vnet_name" {
  value       = azurerm_virtual_network.this.name
  description = "Virtual network name."
}

output "vnet_id" {
  value       = azurerm_virtual_network.this.id
  description = "Virtual network resource ID."
}

output "subnet_ids" {
  value = {
    GatewaySubnet      = azurerm_subnet.gateway.id
    ManagedInstance    = azurerm_subnet.managed_instance.id
    Management         = azurerm_subnet.management.id
    TeamJumpbox        = azurerm_subnet.team_jumpbox.id
    AzureBastionSubnet = azurerm_subnet.bastion.id
    snet-appservice    = azurerm_subnet.appservice.id
    fabric_vnet        = azurerm_subnet.fabric.id
    StreamingVnet      = azurerm_subnet.streaming.id
  }
  description = "Map of subnet name to resource ID."
}

output "sql_mi_nsg_id" {
  value       = azurerm_network_security_group.sql_mi.id
  description = "SQL Managed Instance NSG resource ID."
}

output "sql_mi_nsg_name" {
  value       = azurerm_network_security_group.sql_mi.name
  description = "SQL Managed Instance NSG name."
}


output "bastion_nsg_id" {
  description = "ID of Bastion NSG"
  value       = azurerm_network_security_group.bastion.id
}

output "management_nsg_id" {
  description = "ID of Management NSG"
  value       = azurerm_network_security_group.management.id
}

output "team_jumpbox_nsg_id" {
  description = "ID of Team Jumpbox NSG"
  value       = azurerm_network_security_group.team_jumpbox.id
}

output "appservice_nsg_id" {
  description = "ID of App Service NSG"
  value       = azurerm_network_security_group.appservice.id
}

output "fabric_nsg_id" {
  description = "ID of Fabric NSG"
  value       = azurerm_network_security_group.fabric.id
}

output "streaming_nsg_id" {
  description = "ID of Streaming NSG"
  value       = azurerm_network_security_group.streaming.id
}

output "route_table_id" {
  value       = azurerm_route_table.sql_mi.id
  description = "Route table resource ID for the ManagedInstance subnet."
}
