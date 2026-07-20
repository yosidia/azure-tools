output "storage_account_id" {
  description = "The ID of the Storage Account."
  value       = azurerm_storage_account.storage_account.id
}

output "storage_account_name" {
  description = "The name of the Storage Account."
  value       = azurerm_storage_account.storage_account.name
}

output "primary_blob_endpoint" {
  description = "The primary blob endpoint of the Storage Account."
  value       = azurerm_storage_account.storage_account.primary_blob_endpoint
}

output "primary_access_key" {
  description = "The name of the Storage Account."
  value       = azurerm_storage_account.storage_account.primary_access_key
}