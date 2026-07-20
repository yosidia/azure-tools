output "private_endpoint_id" {
  value = azurerm_private_endpoint.pe.id
}

output "private_endpoint_ip_addresses" {
  value = azurerm_private_endpoint.pe.private_service_connection[0].private_ip_address
}

output "private_endpoint_network_interface_id" {
  value = azurerm_private_endpoint.pe.network_interface[0].id
}