terraform {
  required_providers {
    azapi = {
      source = "Azure/azapi"
    }
  }
}

data "azurerm_client_config" "current" {}

resource "time_sleep" "before_sql_mi" {
  create_duration = "120s"
}

resource "azurerm_mssql_managed_instance" "this" {
  name                = var.instance_name
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.subnet_id

  depends_on = [
    time_sleep.before_sql_mi,
  ]

  identity {
    type = "SystemAssigned"
  }

  administrator_login          = var.administrator_login
  administrator_login_password = var.administrator_login_password

  license_type                 = "LicenseIncluded"
  sku_name                     = "GP_Gen5"
  vcores                       = 4
  storage_size_in_gb           = 96
  storage_account_type         = "LRS"
  proxy_override               = "Default"
  public_data_endpoint_enabled = true

  database_format = "AlwaysUpToDate"


  tags = merge(var.tags, {
    environment = var.env_name
  })

  timeouts {
    create = "12h"
    update = "12h"
    delete = "12h"
  }

  lifecycle {
    ignore_changes = [
      proxy_override
    ]
  }


}

# resource "azapi_update_resource" "sql_mi_update_policy" {
#   type        = "Microsoft.Sql/managedInstances@2023-08-01-preview"
#   resource_id = azurerm_mssql_managed_instance.this.id

#   body = {
#     properties = {
#       databaseFormat = "SQLServer2025"
#     }
#   }

#   depends_on = [
#     azurerm_mssql_managed_instance.this,
#   ]
# }

# SQL MI identity must be able to query Entra ID principals when creating
# azurerm_mssql_managed_instance_active_directory_administrator.
resource "azuread_directory_role" "directory_readers" {
  display_name = "Directory Readers"
}

resource "azuread_directory_role_assignment" "sql_mi_directory_readers" {
  role_id             = azuread_directory_role.directory_readers.object_id
  principal_object_id = azurerm_mssql_managed_instance.this.identity[0].principal_id
  lifecycle {
    ignore_changes = [
      role_id
    ]
  }
}

# Entra directory-role assignments are eventually consistent. Give the grant time
# to propagate before the SQL MI identity uses it to look up the AAD admin,
# otherwise the API returns ServicePrincipalLookupInAadFailedIdentityForbidden.
resource "time_sleep" "after_directory_readers" {
  create_duration = "300s"

  triggers = {
    role_assignment_id = azuread_directory_role_assignment.sql_mi_directory_readers.id
  }

  depends_on = [
    azuread_directory_role_assignment.sql_mi_directory_readers,
  ]
}

resource "azurerm_mssql_managed_instance_active_directory_administrator" "this" {
  managed_instance_id = azurerm_mssql_managed_instance.this.id
  login_username      = var.entra_admin_login
  object_id           = var.entra_admin_object_id
  tenant_id           = data.azurerm_client_config.current.tenant_id

  depends_on = [
    time_sleep.after_directory_readers,
  ]
}



resource "azurerm_network_security_rule" "sql_mi_inbound_3342_internet" {
  name                        = "allow-sqlmi-inbound-tcp-3342-internet"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3342"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = var.sql_mi_nsg_name

  depends_on = [
    azurerm_mssql_managed_instance.this,
  ]


}


