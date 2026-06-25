output "resource_group_name" {
  value       = module.resource_group.name
  description = "Name of the provisioned resource group."
}

output "resource_group_id" {
  value       = module.resource_group.id
  description = "Resource ID of the provisioned resource group."
}

output "vnet_name" {
  value       = module.vnet.vnet_name
  description = "Name of the provisioned virtual network."
}

output "vnet_id" {
  value       = module.vnet.vnet_id
  description = "Resource ID of the provisioned virtual network."
}

output "subnet_ids" {
  value       = module.vnet.subnet_ids
  description = "Map of subnet name to subnet resource ID."
}

output "sql_managed_instance_id" {
  value       = module.sql_managed_instance.id
  description = "SQL Managed Instance resource ID."
}

output "sql_managed_instance_name" {
  value       = module.sql_managed_instance.name
  description = "SQL Managed Instance name."
}

output "sql_managed_instance_fqdn" {
  value       = module.sql_managed_instance.fqdn
  description = "SQL Managed Instance FQDN."
}

output "app_service_plan_id" {
  value       = module.app_service_linux.service_plan_id
  description = "Linux App Service Plan resource ID."
}

output "app_service_plan_name" {
  value       = module.app_service_linux.service_plan_name
  description = "Linux App Service Plan name."
}

output "app_service_web_app_id" {
  value       = module.app_service_linux.web_app_id
  description = "Linux Web App resource ID."
}

output "app_service_web_app_name" {
  value       = module.app_service_linux.web_app_name
  description = "Linux Web App name."
}

output "AZURE_APP_SERVICE_WEB_APP_NAME" {
  value       = module.app_service_linux.web_app_name
  description = "Linux Web App name used by azd service deployment binding."
}

output "app_service_default_hostname" {
  value       = module.app_service_linux.default_hostname
  description = "Linux Web App default hostname."
}

output "backup_storage_account_name" {
  value       = module.storage_account_backups.storage_account_name
  description = "Storage account name used for database backup files."
}

output "backup_storage_container_name" {
  value       = module.storage_account_backups.container_name
  description = "Blob container name containing uploaded database backups."
}

output "backup_blob_names" {
  value       = module.storage_account_backups.blob_names
  description = "List of uploaded database backup blob names."
}

output "user_data_storage_account_name" {
  value       = module.user_data_storage.storage_account_name
  description = "Storage account name used for per-user employee CSV containers."
}

output "user_data_container_names" {
  value       = module.user_data_storage.container_names
  description = "Container names created per user for employee CSV data."
}

output "user_data_blob_name" {
  value       = module.user_data_storage.blob_name
  description = "Employee CSV blob name uploaded into each user container."
}

output "fabric_capacity_arm_id" {
  value       = module.fabric_platform.capacity_arm_id
  description = "Azure Resource Manager ID of the Fabric capacity resource."
}

# output "fabric_capacity_id" {
#   value       = module.fabric_platform.capacity_id
#   description = "Fabric capacity ID used by workspaces and gateway."
# }

output "fabric_capacity_name" {
  value       = module.fabric_platform.capacity_name
  description = "Fabric capacity name."
}

output "fabric_gateway_id" {
  value       = module.fabric_platform.gateway_id
  description = "Fabric gateway ID."
}

output "fabric_gateway_name" {
  value       = module.fabric_platform.gateway_name
  description = "Fabric gateway display name."
}

output "fabric_workspace_names" {
  value       = module.fabric_platform.workspace_names
  description = "Per-user Fabric workspace names."
}

output "fabric_workspace_ids" {
  value       = module.fabric_platform.workspace_ids
  description = "Map of Fabric workspace names to workspace IDs."
}

output "ttyd_user_principal_names" {
  value       = module.ttyd_test_users.user_principal_names
  description = "User principal names for the created TTYD test users."
}

output "ttyd_user_object_ids" {
  value       = module.ttyd_test_users.user_object_ids
  description = "Object IDs for the created TTYD test users."
}

output "ttyd_group_name" {
  value       = module.ttyd_test_users.group_name
  description = "Display name of the TTYD Entra ID group."
}

output "ttyd_group_object_id" {
  value       = module.ttyd_test_users.group_object_id
  description = "Object ID of the TTYD Entra ID group."
}
