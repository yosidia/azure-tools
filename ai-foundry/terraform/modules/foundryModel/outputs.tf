output "deployment_id" {
  description = "The resource ID of the AI Foundry model deployment"
  value       = azapi_resource.aifoundry_deployment_gpt.id
}

output "deployment_name" {
  description = "The name of the AI Foundry model deployment"
  value       = azapi_resource.aifoundry_deployment_gpt.name
}
