locals {
  normalized_env     = lower(replace(var.env_name, "-", ""))
  generated_sa_name  = substr("stuserdata${local.normalized_env}", 0, 24)
  effective_sa_name  = coalesce(var.storage_account_name, local.generated_sa_name)
  container_names    = [for i in range(var.user_count) : format("%s%03d", var.container_name_prefix, i + 1)]
  containers_by_name = { for name in local.container_names : name => name }
  container_name_by_user_key = {
    for idx, name in local.container_names : format("%03d", idx + 1) => name
  }
  employee_blob_name = basename(var.employee_csv_path)
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
  is_hns_enabled                  = true

  tags = merge(var.tags, {
    environment = var.env_name
  })
}

resource "azurerm_storage_container" "user_data" {
  for_each = local.containers_by_name

  name                  = each.key
  storage_account_name  = azurerm_storage_account.this.name
  container_access_type = "private"

  depends_on = [
    azurerm_storage_account.this
  ]
}

resource "azurerm_storage_blob" "employee_data" {
  for_each = azurerm_storage_container.user_data

  name                   = local.employee_blob_name
  storage_account_name   = azurerm_storage_account.this.name
  storage_container_name = each.value.name
  type                   = "Block"
  source                 = var.employee_csv_path

  depends_on = [
    azurerm_storage_container.user_data
  ]
}

resource "azurerm_role_assignment" "group_blob_reader" {
  name                 = uuidv5("url", "${azurerm_storage_account.this.id}|${var.ttyd_group_object_id}|Storage Blob Data Reader")
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = var.ttyd_group_object_id
  principal_type       = "Group"

  lifecycle {
    ignore_changes = [principal_type]
  }

  depends_on = [
    azurerm_storage_account.this
  ]
}

resource "azurerm_role_assignment" "user_container_blob_owner" {
  for_each = var.user_object_id_map

  scope                = "${azurerm_storage_account.this.id}/blobServices/default/containers/${local.container_name_by_user_key[each.key]}"
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = each.value

  lifecycle {
    precondition {
      condition     = contains(keys(local.container_name_by_user_key), each.key)
      error_message = "Each user_object_id_map key must match a generated container index (e.g. 001)."
    }
  }

  depends_on = [
    azurerm_storage_blob.employee_data
  ]
}
