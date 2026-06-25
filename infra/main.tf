locals {
  common_tags = {
    SecurityControl = "Ignore"
  }
}

module "resource_group" {
  source              = "./modules/resource_group"
  name                = "rg-sqlhack-${var.ENV_NAME}"
  location            = var.LOCATION
  assign_reader_role  = true
  reader_principal_id = module.ttyd_test_users.group_object_id
  tags                = local.common_tags
}

module "vnet" {
  source              = "./modules/vnet"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  env_name            = var.ENV_NAME
  tags                = local.common_tags
}

module "sql_managed_instance" {
  source = "./modules/sql_managed_instance"

  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  env_name            = var.ENV_NAME
  subnet_id           = module.vnet.subnet_ids["ManagedInstance"]

  instance_name                = "sqlhackmi-${var.ENV_NAME}"
  administrator_login          = var.SQL_ADMIN_LOGIN
  administrator_login_password = var.SQL_PASSWORD
  entra_admin_login            = var.SQL_MI_ENTRA_ADMIN_LOGIN
  entra_admin_object_id        = var.SQL_MI_ENTRA_ADMIN_OBJECT_ID

  sql_mi_nsg_name                = module.vnet.sql_mi_nsg_name
  sql_mi_nsg_resource_group_name = module.resource_group.name

  tags = local.common_tags
}

module "app_service_linux" {
  source = "./modules/app_service_linux"

  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  env_name            = var.ENV_NAME
  subnet_id           = module.vnet.subnet_ids["snet-appservice"]

  sql_database    = "TailspinToys_Demo_Final"
  sql_password    = var.SQL_PASSWORD
  sql_server_fqdn = module.sql_managed_instance.fqdn
  sql_admin_login = var.SQL_ADMIN_LOGIN

  tags = local.common_tags
}

module "storage_account_backups" {
  source = "./modules/storage_account_backups"

  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  env_name            = var.ENV_NAME
  container_name      = "build"

  backup_files = [
    "${path.root}/../databasebackup/tailspintoys_before_launch.bak",
    "${path.root}/../databasebackup/tailspintoysfeedback_before_launch.bak"
  ]

  tags = local.common_tags
}

module "user_data_storage" {
  source = "./modules/user_data_storage"

  resource_group_name   = module.resource_group.name
  location              = module.resource_group.location
  env_name              = var.ENV_NAME
  user_count            = var.TAILSPIN_TOYS_USER_DATABASE_COUNT
  employee_csv_path     = "${path.root}/../csvdata/employees_user_data.csv"
  container_name_prefix = "container"
  user_object_id_map    = module.ttyd_test_users.user_object_id_map
  ttyd_group_object_id  = module.ttyd_test_users.group_object_id

  tags = local.common_tags
}

module "fabric_platform" {
  source = "./modules/fabric_platform"

  resource_group_name  = module.resource_group.name
  location             = module.resource_group.location
  env_name             = var.ENV_NAME
  subscription_id      = var.SUBSCRIPTIONID
  virtual_network_name = module.vnet.vnet_name
  fabric_subnet_name   = "fabric_vnet"
  user_count           = var.TAILSPIN_TOYS_USER_DATABASE_COUNT
  capacity_admin_members = [
    var.SQL_MI_ENTRA_ADMIN_LOGIN
  ]
  user_object_id_map   = module.ttyd_test_users.user_object_id_map
  ttyd_group_object_id = module.ttyd_test_users.group_object_id
  tags                 = local.common_tags
  depends_on = [
  module.vnet]

}

module "ttyd_test_users" {
  source           = "./modules/ttyd_test_users"
  user_count       = var.TAILSPIN_TOYS_USER_DATABASE_COUNT
  environment_name = var.ENV_NAME
}

moved {
  from = module.network_security.azurerm_network_security_group.bastion
  to   = module.vnet.azurerm_network_security_group.bastion
}

moved {
  from = module.network_security.azurerm_network_security_group.management
  to   = module.vnet.azurerm_network_security_group.management
}

moved {
  from = module.network_security.azurerm_network_security_group.team_jumpbox
  to   = module.vnet.azurerm_network_security_group.team_jumpbox
}

moved {
  from = module.network_security.azurerm_network_security_group.appservice
  to   = module.vnet.azurerm_network_security_group.appservice
}

moved {
  from = module.network_security.azurerm_network_security_group.fabric
  to   = module.vnet.azurerm_network_security_group.fabric
}

moved {
  from = module.network_security.azurerm_network_security_group.streaming
  to   = module.vnet.azurerm_network_security_group.streaming
}

moved {
  from = module.network_security.azurerm_subnet_network_security_group_association.management
  to   = module.vnet.azurerm_subnet_network_security_group_association.management
}

moved {
  from = module.network_security.azurerm_subnet_network_security_group_association.team_jumpbox
  to   = module.vnet.azurerm_subnet_network_security_group_association.team_jumpbox
}

moved {
  from = module.network_security.azurerm_subnet_network_security_group_association.bastion
  to   = module.vnet.azurerm_subnet_network_security_group_association.bastion
}

moved {
  from = module.network_security.azurerm_subnet_network_security_group_association.appservice
  to   = module.vnet.azurerm_subnet_network_security_group_association.appservice
}

moved {
  from = module.network_security.azurerm_subnet_network_security_group_association.fabric
  to   = module.vnet.azurerm_subnet_network_security_group_association.fabric
}

moved {
  from = module.network_security.azurerm_subnet_network_security_group_association.streaming
  to   = module.vnet.azurerm_subnet_network_security_group_association.streaming
}
