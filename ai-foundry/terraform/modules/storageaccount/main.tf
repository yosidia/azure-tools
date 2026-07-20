resource "azurerm_storage_account" "storage_account" {
  name                            = var.sa_name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = var.account_tier
  account_replication_type        = var.account_replication_type
  public_network_access_enabled   = var.public_network_access_enabled
  allow_nested_items_to_be_public = var.allow_nested_items_to_be_public
  lifecycle {
    ignore_changes = [
      # Ignore changes to the 'tags' attribute
      tags,
    ]
  }
}

module "private_endpoint_blob_pe" {
  source                        = "../privateEndpoint"
  count                         = var.pe_blob_count
  private_endpoint_name         = lower("${var.sa_name}-blob-pe-01")
  location                      = var.location
  resource_group_name           = var.resource_group_name
  subnet_id                     = var.sa_subnet_id
  custom_network_interface_name = lower("${var.sa_name}-blob-pe-01-nic")
  private_dns_zone_ids          = [var.private_dns_zone_id_blob]
  service_connection_name       = lower("${var.sa_name}-blob-pe-01")
  target_resource_id            = azurerm_storage_account.storage_account.id
  subresource_names             = ["blob"]
}

module "private_endpoint_dfs_pe" {
  source                        = "../privateEndpoint"
  count                         = var.pe_dfs_count
  private_endpoint_name         = lower("${var.sa_name}-dfs-pe-02")
  location                      = var.location
  resource_group_name           = var.resource_group_name
  subnet_id                     = var.sa_subnet_id
  custom_network_interface_name = lower("${var.sa_name}-dfs-pe-02-nic")
  private_dns_zone_ids          = [var.private_dns_zone_id_dfs]
  service_connection_name       = lower("${var.sa_name}-dfs-pe-02")
  target_resource_id            = azurerm_storage_account.storage_account.id
  subresource_names             = ["dfs"]
}

module "private_endpoint_table_pe" {
  source                        = "../privateEndpoint"
  count                         = var.pe_table_count
  private_endpoint_name         = lower("${var.sa_name}-table-pe-03")
  location                      = var.location
  resource_group_name           = var.resource_group_name
  subnet_id                     = var.sa_subnet_id
  custom_network_interface_name = lower("${var.sa_name}-table-pe-03-nic")
  private_dns_zone_ids          = [var.private_dns_zone_id_table]
  service_connection_name       = lower("${var.sa_name}-table-pe-03")
  target_resource_id            = azurerm_storage_account.storage_account.id
  subresource_names             = ["table"]
}

resource "azurerm_storage_container" "storage_container_1" {
  name               = "dataroot"
  storage_account_id = azurerm_storage_account.storage_account.id
}
