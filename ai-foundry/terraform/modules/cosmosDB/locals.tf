############################################################
# Module-local configuration for the Cosmos DB module.
# Values come from native Terraform variables (see variables.tf).
############################################################
locals {
  offer_type                       = var.offer_type
  kind                             = var.kind
  free_tier_enabled                = var.free_tier_enabled
  local_authentication_disabled    = var.local_authentication_disabled
  public_network_access_enabled    = var.public_network_access_enabled
  automatic_failover_enabled       = var.automatic_failover_enabled
  multiple_write_locations_enabled = var.multiple_write_locations_enabled
  consistency_level                = var.consistency_level
  failover_priority                = var.failover_priority
  zone_redundant                   = var.zone_redundant
  private_endpoint_suffix          = var.private_endpoint_suffix
  subresource_names                = var.subresource_names

  private_endpoint_name = lower("${var.account_name}-${local.private_endpoint_suffix}")
  nic_name              = lower("${var.account_name}-${local.private_endpoint_suffix}-nic")
}
