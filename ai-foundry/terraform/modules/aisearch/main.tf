resource "azurerm_search_service" "ai_search_service" {
  name                          = var.search_service_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = var.sku
  replica_count                 = var.replica_count
  partition_count               = var.partition_count
  public_network_access_enabled = var.public_network_access_enabled

  identity {
    type = var.identity_type
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes to the 'tags' attribute
      tags,
    ]
  }

  tags = var.tags
}

module "private_endpoint" {
  source                        = "../privateEndpoint"
  private_endpoint_name         = lower("${var.search_service_name}-pe-01")
  location                      = var.location
  resource_group_name           = var.resource_group_name
  subnet_id                     = var.ais_subnet_id
  custom_network_interface_name = lower("${var.search_service_name}-pe-01-nic")
  private_dns_zone_ids          = var.private_dns_zone_ids
  service_connection_name       = lower("${var.search_service_name}-pe-01")
  target_resource_id            = azurerm_search_service.ai_search_service.id
  subresource_names             = ["searchService"]
}
