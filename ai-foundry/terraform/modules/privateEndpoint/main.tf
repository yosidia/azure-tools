resource "azurerm_private_endpoint" "pe" {
  name                          = lower(var.private_endpoint_name)
  location                      = var.location
  resource_group_name           = var.resource_group_name
  subnet_id                     = var.subnet_id
  custom_network_interface_name = var.custom_network_interface_name

  private_dns_zone_group {
    name                 = lower(var.dns_zone_group_name)
    private_dns_zone_ids = var.private_dns_zone_ids
  }

  private_service_connection {
    name                           = lower(var.service_connection_name)
    private_connection_resource_id = var.target_resource_id
    is_manual_connection           = var.is_manual_connection
    subresource_names              = var.subresource_names
  }
  lifecycle {
    ignore_changes = [
      # Ignore changes to the 'tags' attribute
      tags,
    ]
  }
}
