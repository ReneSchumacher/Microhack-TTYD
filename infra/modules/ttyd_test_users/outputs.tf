output "user_principal_names" {
  value       = [for user in azuread_user.this : user.user_principal_name]
  description = "User principal names for the created TTYD test users."
}

output "user_object_ids" {
  value       = [for user in azuread_user.this : user.object_id]
  description = "Object IDs for the created TTYD test users."
}

output "user_object_id_map" {
  value       = { for key, user in azuread_user.this : key => user.object_id }
  description = "Map of zero-padded user index to Entra object ID."
}

output "group_name" {
  value       = azuread_group.this.display_name
  description = "Display name of the TTYD Entra ID group."
}

output "group_object_id" {
  value       = azuread_group.this.object_id
  description = "Object ID of the TTYD Entra ID group."
}
