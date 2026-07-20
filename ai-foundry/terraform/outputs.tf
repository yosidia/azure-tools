output "resource_group_name" {
  description = "Resource group hosting the AI Foundry stack."
  value       = azurerm_resource_group.ai.name
}

output "foundry_id" {
  description = "AI Foundry account resource ID."
  value       = module.ai_services.foundry_id
}

output "foundry_name" {
  description = "AI Foundry account name."
  value       = module.ai_services.foundry_name
}

output "foundry_project_id" {
  description = "Default AI Foundry project resource ID."
  value       = module.foundry_project_default.foundry_project_id
}

output "ai_search_service_id" {
  description = "Azure AI Search service resource ID."
  value       = module.ai_search_service_ai.search_service_id
}

output "cosmosdb_account_id" {
  description = "Cosmos DB account resource ID."
  value       = module.cosmosdb_ai.cosmosdb_id
}

output "storage_account_id" {
  description = "Storage account resource ID."
  value       = module.storage_account.storage_account_id
}

output "application_insights_id" {
  description = "Private Application Insights component resource ID."
  value       = module.monitoring.app_insights_id
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID."
  value       = module.monitoring.log_analytics_workspace_id
}

output "ampls_id" {
  description = "Azure Monitor Private Link Scope (AMPLS) resource ID."
  value       = module.monitoring.ampls_id
}
