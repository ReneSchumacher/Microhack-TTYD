variable "resource_group_name" {
  type        = string
  description = "Name of the resource group where user data storage is created."
}

variable "location" {
  type        = string
  description = "Azure region for storage resources."
}

variable "env_name" {
  type        = string
  description = "Environment suffix used for naming and tagging."
}

variable "user_count" {
  type        = number
  description = "Number of user containers to create."

  validation {
    condition     = var.user_count >= 1
    error_message = "user_count must be at least 1."
  }
}

variable "employee_csv_path" {
  type        = string
  description = "Absolute path to employees_user_data.csv that is uploaded to every container."
}

variable "container_name_prefix" {
  type        = string
  description = "Prefix for generated container names."
  default     = "container"
}

variable "storage_account_name" {
  type        = string
  description = "Optional explicit storage account name. If null, a deterministic name is generated."
  default     = null
}

variable "user_object_id_map" {
  type        = map(string)
  description = "Map of zero-padded user index (e.g. 001) to Entra object ID for per-container RBAC assignments."

  validation {
    condition     = length(var.user_object_id_map) == var.user_count
    error_message = "user_object_id_map must include exactly one entry per user_count."
  }
}

variable "ttyd_group_object_id" {
  type        = string
  description = "Object ID of the TTYD users Entra group granted Storage Blob Data Reader on the storage account."

  validation {
    condition     = length(trimspace(var.ttyd_group_object_id)) > 0
    error_message = "ttyd_group_object_id must not be empty."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources created by this module."
  default     = {}
}
