variable "resource_group_name" {
  type        = string
  description = "Resource group name used by the Fabric gateway VNet binding."
}

variable "location" {
  type        = string
  description = "Azure region for Fabric capacity."
}

variable "env_name" {
  type        = string
  description = "Environment suffix used for naming."
}

variable "subscription_id" {
  type        = string
  description = "Azure subscription ID containing the VNet and Fabric capacity."
}

variable "virtual_network_name" {
  type        = string
  description = "Virtual network name used by the Fabric gateway."
}

variable "fabric_subnet_name" {
  type        = string
  description = "Subnet name used by the Fabric virtual network gateway integration."
}

variable "user_count" {
  type        = number
  description = "Number of per-user Fabric workspaces to create."

  validation {
    condition     = var.user_count >= 1
    error_message = "user_count must be at least 1."
  }
}

variable "capacity_admin_members" {
  type        = list(string)
  description = "Fabric capacity administrator identities."

  validation {
    condition     = length(var.capacity_admin_members) >= 1
    error_message = "capacity_admin_members must contain at least one administrator identity."
  }
}

variable "user_object_id_map" {
  type        = map(string)
  description = "Map of zero-padded user index to Entra object ID for workspace role assignments."

  validation {
    condition     = length(var.user_object_id_map) >= 1
    error_message = "user_object_id_map must contain at least one user mapping."
  }
}

variable "ttyd_group_object_id" {
  type        = string
  description = "Entra object ID of the TTYDUsers group granted access to the Fabric data gateway."
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources created by this module."
  default     = {}
}
