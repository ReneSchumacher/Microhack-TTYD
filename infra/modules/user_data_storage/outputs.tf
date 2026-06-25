output "storage_account_id" {
  value       = azurerm_storage_account.this.id
  description = "Storage account resource ID for user data."
}

output "storage_account_name" {
  value       = azurerm_storage_account.this.name
  description = "Storage account name for user data."
}

output "container_names" {
  value       = sort(keys(azurerm_storage_container.user_data))
  description = "List of user data container names."
}

output "blob_name" {
  value       = basename(var.employee_csv_path)
  description = "Blob name uploaded into each container."
}
