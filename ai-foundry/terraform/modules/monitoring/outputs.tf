output "app_insights_id" {
  description = "Application Insights component resource ID."
  value       = azurerm_application_insights.appi.id
}

output "app_insights_name" {
  description = "Application Insights component name."
  value       = azurerm_application_insights.appi.name
}

output "app_insights_connection_string" {
  description = "Application Insights connection string."
  value       = azurerm_application_insights.appi.connection_string
  sensitive   = true
}

output "app_insights_instrumentation_key" {
  description = "Application Insights instrumentation key."
  value       = azurerm_application_insights.appi.instrumentation_key
  sensitive   = true
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID."
  value       = azurerm_log_analytics_workspace.law.id
}

output "ampls_id" {
  description = "Azure Monitor Private Link Scope resource ID."
  value       = azurerm_monitor_private_link_scope.ampls.id
}

output "ampls_name" {
  description = "Azure Monitor Private Link Scope name."
  value       = azurerm_monitor_private_link_scope.ampls.name
}
