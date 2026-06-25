variable "name" {
  type        = string
  description = "Name of the resource group."
}

variable "location" {
  type        = string
  description = "Azure region for the resource group."
}

variable "assign_reader_role" {
  type        = bool
  description = "Whether to assign a Reader role on the resource group."
  default     = false
}

variable "reader_principal_id" {
  type        = string
  description = "Object ID of the principal that should receive Reader on this resource group."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources created by this module."
  default     = {}
}
