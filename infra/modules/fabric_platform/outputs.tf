output "capacity_arm_id" {
  value       = azurerm_fabric_capacity.capacity.id
  description = "Azure Resource Manager ID of the Fabric capacity resource."
}

# output "capacity_id" {
#   value       = data.fabric_capacity.capacity.id
#   description = "Fabric capacity ID used by workspaces and gateway."
# }

output "capacity_name" {
  value       = azurerm_fabric_capacity.capacity.name
  description = "Fabric capacity name."
}

output "gateway_id" {
  value       = fabric_gateway.this.id
  description = "Fabric gateway ID."
}

output "gateway_name" {
  value       = fabric_gateway.this.display_name
  description = "Fabric gateway display name."
}

output "workspace_names" {
  value       = sort(keys(fabric_workspace.user))
  description = "Per-user Fabric workspace names."
}

output "workspace_ids" {
  value       = { for name, workspace in fabric_workspace.user : name => workspace.id }
  description = "Map of workspace display name to Fabric workspace ID."
}
