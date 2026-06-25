variable "resource_group_name" {
  type        = string
  description = "Name of the resource group for App Service resources."
}

variable "location" {
  type        = string
  description = "Azure region for App Service resources."
}

variable "env_name" {
  type        = string
  description = "Environment name used in resource naming."
}

variable "subnet_id" {
  type        = string
  description = "Subnet resource ID used for App Service VNet integration."
}

variable "sql_database" {
  type        = string
  description = "SQL database name provided to the web app as app setting."
  default     = "TailspinToys_Demo_Final"
}

variable "sql_password" {
  type        = string
  description = "SQL password provided to the web app as app setting."
  sensitive   = true
}

variable "sql_server_fqdn" {
  type        = string
  description = "SQL server FQDN provided to the web app as app setting."
}

variable "sql_admin_login" {
  type        = string
  description = "SQL admin login provided to the web app as app setting."
}

variable "service_plan_name" {
  type        = string
  description = "App Service plan name."
  default     = null
}

variable "web_app_name" {
  type        = string
  description = "Linux Web App name."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources created by this module."
  default     = {}
}
