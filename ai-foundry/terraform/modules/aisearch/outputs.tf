output "search_service_id" {
  description = "Resource ID of the Azure AI Search service."
  value       = azurerm_search_service.ai_search_service.id
}

output "search_service_name" {
  description = "Name of the Azure AI Search service."
  value       = azurerm_search_service.ai_search_service.name
}
