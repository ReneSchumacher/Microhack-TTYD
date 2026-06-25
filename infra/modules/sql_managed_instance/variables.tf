variable "resource_group_name" {
  type        = string
  description = "Resource group name."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "env_name" {
  type        = string
  description = "Environment name for tagging."
}

variable "subnet_id" {
  type        = string
  description = "Managed Instance delegated subnet ID."
}

variable "instance_name" {
  type        = string
  description = "SQL Managed Instance name."
}

variable "administrator_login" {
  type        = string
  description = "SQL Managed Instance admin login."
}

variable "administrator_login_password" {
  type        = string
  description = "SQL Managed Instance admin password."
  sensitive   = true
}

variable "entra_admin_login" {
  type        = string
  description = "Entra admin login (UPN or display name)."
}

variable "entra_admin_object_id" {
  type        = string
  description = "Entra admin object ID."
}

variable "sql_mi_nsg_name" {
  type        = string
  description = "Name of the SQL Managed Instance NSG."
}

variable "sql_mi_nsg_resource_group_name" {
  type        = string
  description = "Resource group name where the SQL MI NSG is located."
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources created by this module."
  default     = {}
}
