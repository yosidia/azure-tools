output "foundry_id" {
  description = "Resource ID of the AI Foundry (Cognitive Services) account."
  value       = azapi_resource.ai_foundry.id
}

output "foundry_name" {
  description = "Name of the AI Foundry account."
  value       = azapi_resource.ai_foundry.name
}

output "principal_id" {
  description = "Map of system-assigned managed identity principal IDs, keyed by foundry instance. Use for downstream RBAC role assignments."
  value       = { for k, r in azapi_resource.ai_foundry : k => try(r.identity[0].principal_id, null) }
}

output "custom_subdomain" {
  description = "Custom subdomain configured on the account (required for Entra-ID data-plane auth)."
  value       = local.custom_subdomain
}

output "endpoint" {
  description = "Primary endpoint of the AI Foundry account."
  value       = "https://${local.custom_subdomain}.cognitiveservices.azure.com/"
}

output "private_endpoint_id" {
  description = "Resource ID of the account private endpoint."
  value       = module.private_endpoint_account_pe.private_endpoint_id
}

output "model_deployment_id" {
  description = "Resource ID of the default model deployment, or null if not enabled."
  value       = var.enable_default_model_deployment ? azurerm_cognitive_deployment.aifoundry_model_deployment[0].id : null
}

output "model_deployment_name" {
  description = "Name of the default model deployment, or null if not enabled."
  value       = var.enable_default_model_deployment ? azurerm_cognitive_deployment.aifoundry_model_deployment[0].name : null
}