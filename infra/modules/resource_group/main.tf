resource "azurerm_resource_group" "this" {
  name     = var.name
  location = var.location
  tags     = var.tags
}

resource "azurerm_role_assignment" "reader" {
  count                = var.assign_reader_role ? 1 : 0
  scope                = azurerm_resource_group.this.id
  role_definition_name = "Reader"
  principal_id         = var.reader_principal_id
}
