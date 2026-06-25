locals {
  normalized_env       = lower(replace(var.env_name, "-", ""))
  generated_sa_name    = substr("stsqlhack${local.normalized_env}", 0, 24)
  effective_sa_name    = coalesce(var.storage_account_name, local.generated_sa_name)
  backup_files_by_name = { for file_path in var.backup_files : basename(file_path) => file_path }
}

resource "azurerm_storage_account" "this" {
  name                            = local.effective_sa_name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  allow_nested_items_to_be_public = false
  min_tls_version                 = "TLS1_2"
  local_user_enabled              = false

  tags = merge(var.tags, {
    environment = var.env_name
  })
}

resource "azurerm_storage_container" "this" {
  name                  = var.container_name
  storage_account_name  = azurerm_storage_account.this.name
  container_access_type = "private"
}

resource "azurerm_storage_blob" "backup" {
  for_each = local.backup_files_by_name

  name                   = each.key
  storage_account_name   = azurerm_storage_account.this.name
  storage_container_name = azurerm_storage_container.this.name
  type                   = "Block"
  source                 = each.value
}
