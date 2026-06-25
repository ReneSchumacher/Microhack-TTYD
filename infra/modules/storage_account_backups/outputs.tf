output "storage_account_id" {
  value       = azurerm_storage_account.this.id
  description = "Storage account resource ID."
}

output "storage_account_name" {
  value       = azurerm_storage_account.this.name
  description = "Storage account name."
}

output "container_name" {
  value       = azurerm_storage_container.this.name
  description = "Blob container name for uploaded backups."
}

output "blob_names" {
  value       = keys(azurerm_storage_blob.backup)
  description = "List of uploaded blob names."
}

output "storage_account_primary_access_key" {
  value       = azurerm_storage_account.this.primary_access_key
  description = "Primary access key for storage account (used for backup restore)."
  sensitive   = true
}
