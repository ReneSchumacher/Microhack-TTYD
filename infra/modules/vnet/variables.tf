variable "resource_group_name" {
  type        = string
  description = "Name of the resource group to deploy the VNet into."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "env_name" {
  type        = string
  description = "AZD environment name (used for tagging)."
}

variable "vnet_name" {
  type        = string
  description = "Name of the virtual network."
  default     = "SQLHACK-SHARED-vnet"
}

variable "address_space" {
  type        = list(string)
  description = "Address space for the virtual network."
  default     = ["10.0.0.0/16"]
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources created by this module."
  default     = {}
}
