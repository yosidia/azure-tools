output "foundry_project_id" {
  description = "Resource ID of the AI Foundry project."
  value       = azapi_resource.foundry_project.id
}

output "foundry_project_principal_id" {
  description = "System-assigned managed identity principal ID of the AI Foundry project."
  value       = azapi_resource.foundry_project.output.identity.principalId
}

output "foundry_project_internal_id" {
  description = "Internal project ID used by AI Foundry capability host resources."
  value       = local.foundry_project_internal_id
}
