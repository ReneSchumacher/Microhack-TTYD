variable "user_count" {
  type        = number
  description = "Number of test Entra ID users to create."

  validation {
    condition     = var.user_count >= 1
    error_message = "user_count must be at least 1."
  }
}

variable "environment_name" {
  type        = string
  description = "AZD environment name used in the user principal name pattern."

  validation {
    condition     = length(trimspace(var.environment_name)) > 0
    error_message = "environment_name must not be empty."
  }
}
