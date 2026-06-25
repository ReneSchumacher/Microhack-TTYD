variable "LOCATION" {
  type        = string
  description = "Azure region for all resources."
}

variable "ENV_NAME" {
  type        = string
  description = "AZD environment name."
}

variable "SUBSCRIPTIONID" {
  type        = string
  description = "Azure subscription ID."
}

variable "APP_SERVICE_PLAN_SKU" {
  type        = string
  description = "App Service Plan SKU."
  default     = "B1"
}

variable "SQL_MI_ENTRA_ADMIN_LOGIN" {
  type        = string
  description = "SQL Managed Instance Entra admin login."
}

variable "SQL_MI_ENTRA_ADMIN_OBJECT_ID" {
  type        = string
  description = "SQL Managed Instance Entra admin object ID."
}

variable "SQL_PASSWORD" {
  type        = string
  sensitive   = true
  description = "SQL Managed Instance administrator password."
}

variable "SQL_ADMIN_LOGIN" {
  type        = string
  description = "SQL Managed Instance SQL admin login."
}

variable "TAILSPIN_TOYS_USER_DATABASE_COUNT" {
  type        = number
  description = "Number of user containers to create for employee CSV data."
  default     = 5

  validation {
    condition     = var.TAILSPIN_TOYS_USER_DATABASE_COUNT >= 1
    error_message = "TAILSPIN_TOYS_USER_DATABASE_COUNT must be at least 1."
  }
}
