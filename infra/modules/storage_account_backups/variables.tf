variable "resource_group_name" {
  type        = string
  description = "Name of the resource group where the storage account is created."
}

variable "location" {
  type        = string
  description = "Azure region for storage resources."
}

variable "env_name" {
  type        = string
  description = "Environment suffix used for naming and tagging."
}

variable "container_name" {
  type        = string
  description = "Blob container name for database backup files."
  default     = "build"
}

variable "backup_files" {
  type        = list(string)
  description = "Absolute paths to local backup files that should be uploaded as blobs."
}

variable "storage_account_name" {
  type        = string
  description = "Optional explicit storage account name. If null, a deterministic name is generated."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources created by this module."
  default     = {}
}
