output "id" {
  value       = azurerm_mssql_managed_instance.this.id
  description = "Managed Instance resource ID."
}

output "name" {
  value       = azurerm_mssql_managed_instance.this.name
  description = "Managed Instance name."
}

output "fqdn" {
  value       = azurerm_mssql_managed_instance.this.fqdn
  description = "Managed Instance FQDN."
}

output "identity_principal_id" {
  value       = azurerm_mssql_managed_instance.this.identity[0].principal_id
  description = "System-assigned managed identity principal ID."
}
