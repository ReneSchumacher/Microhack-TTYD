output "name" {
  value       = azurerm_resource_group.this.name
  description = "Resource group name."
}

output "id" {
  value       = azurerm_resource_group.this.id
  description = "Resource group resource ID."
}

output "location" {
  value       = azurerm_resource_group.this.location
  description = "Resource group location."
}
