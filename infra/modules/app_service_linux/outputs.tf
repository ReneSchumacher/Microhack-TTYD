output "service_plan_id" {
  value       = azurerm_service_plan.this.id
  description = "App Service Plan resource ID."
}

output "service_plan_name" {
  value       = azurerm_service_plan.this.name
  description = "App Service Plan name."
}

output "web_app_id" {
  value       = azurerm_linux_web_app.this.id
  description = "Linux Web App resource ID."
}

output "web_app_name" {
  value       = azurerm_linux_web_app.this.name
  description = "Linux Web App name."
}

output "default_hostname" {
  value       = azurerm_linux_web_app.this.default_hostname
  description = "Linux Web App default hostname."
}
