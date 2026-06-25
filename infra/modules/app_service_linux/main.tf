terraform {
  required_providers {
    azapi = {
      source = "Azure/azapi"
    }
  }
}

locals {
  service_plan_name = coalesce(var.service_plan_name, "asp-sqlhack-${var.env_name}")
  web_app_name      = coalesce(var.web_app_name, "app-sqlhack-${var.env_name}")
}

resource "azurerm_service_plan" "this" {
  name                = local.service_plan_name
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = "B1"

  tags = merge(var.tags, {
    environment = var.env_name
  })
}

resource "azurerm_linux_web_app" "this" {
  name                = local.web_app_name
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = azurerm_service_plan.this.id

  virtual_network_subnet_id = var.subnet_id

  site_config {}

  app_settings = {
    SQL_DATABASE                   = var.sql_database
    SQL_PASSWORD                   = var.sql_password
    SQL_SERVER                     = var.sql_server_fqdn
    SQL_USER                       = var.sql_admin_login
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
    PORT                           = "3000"
  }

  tags = merge(var.tags, {
    environment = var.env_name
  })
}

resource "azapi_update_resource" "this_runtime_node24" {
  type        = "Microsoft.Web/sites@2022-09-01"
  resource_id = azurerm_linux_web_app.this.id

  body = {
    properties = {
      siteConfig = {
        linuxFxVersion = "NODE|24-lts"
      }
    }
  }
}
