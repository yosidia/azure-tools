resource "azurerm_cosmosdb_account" "cosmosdb" {
  name                = var.account_name
  location            = var.location
  resource_group_name = var.resource_group_name

  offer_type        = local.offer_type
  kind              = local.kind
  free_tier_enabled = local.free_tier_enabled

  local_authentication_disabled = local.local_authentication_disabled
  public_network_access_enabled = local.public_network_access_enabled

  automatic_failover_enabled       = local.automatic_failover_enabled
  multiple_write_locations_enabled = local.multiple_write_locations_enabled

  consistency_policy {
    consistency_level = local.consistency_level
  }

  geo_location {
    location          = var.location
    failover_priority = local.failover_priority
    zone_redundant    = local.zone_redundant
  }
  lifecycle {
    ignore_changes = [
      # Ignore changes to the 'tags' attribute
      tags,
    ]
  }
}

module "private_endpoint" {
  source                        = "../privateEndpoint"
  private_endpoint_name         = local.private_endpoint_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  subnet_id                     = var.private_endpoint_subnet_id
  custom_network_interface_name = local.nic_name
  private_dns_zone_ids          = var.private_dns_zone_ids
  service_connection_name       = local.private_endpoint_name
  target_resource_id            = azurerm_cosmosdb_account.cosmosdb.id
  subresource_names             = local.subresource_names
}

############################################################
# Diagnostic settings -> Log Analytics
############################################################
resource "azurerm_monitor_diagnostic_setting" "cosmosdb" {
  count = var.log_analytics_workspace_id == null ? 0 : 1

  name                       = var.diagnostic_setting_name
  target_resource_id         = azurerm_cosmosdb_account.cosmosdb.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "Requests"
  }
}
