terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0.0"
    }
  }
}

############################################################
# Log Analytics workspace (private)
############################################################
resource "azurerm_log_analytics_workspace" "law" {
  name                = var.workspace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.workspace_sku
  retention_in_days   = var.workspace_retention_in_days

  # Force ingestion/query through Private Link only.
  internet_ingestion_enabled = var.public_network_access_enabled
  internet_query_enabled     = var.public_network_access_enabled

  tags = var.tags

  lifecycle {
    ignore_changes = [tags]
  }
}

############################################################
# Application Insights (workspace-based, private)
############################################################
resource "azurerm_application_insights" "appi" {
  name                = var.app_insights_name
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.law.id
  application_type    = var.app_insights_application_type

  # Force ingestion/query through Private Link only.
  internet_ingestion_enabled = var.public_network_access_enabled
  internet_query_enabled     = var.public_network_access_enabled

  tags = var.tags

  lifecycle {
    ignore_changes = [tags]
  }
}

############################################################
# Azure Monitor Private Link Scope (AMPLS)
#
# Best practice: exactly ONE AMPLS for the environment/region.
# PrivateOnly access mode guarantees telemetry only flows over
# the private endpoint and never the public internet.
############################################################
resource "azurerm_monitor_private_link_scope" "ampls" {
  name                  = var.ampls_name
  resource_group_name   = var.resource_group_name
  ingestion_access_mode = var.ampls_ingestion_access_mode
  query_access_mode     = var.ampls_query_access_mode

  tags = var.tags

  lifecycle {
    ignore_changes = [tags]
  }
}

# Bring the Log Analytics workspace into the AMPLS.
resource "azurerm_monitor_private_link_scoped_service" "law" {
  name                = "${var.workspace_name}-ampls"
  resource_group_name = var.resource_group_name
  scope_name          = azurerm_monitor_private_link_scope.ampls.name
  linked_resource_id  = azurerm_log_analytics_workspace.law.id
}

# Bring the Application Insights component into the AMPLS.
resource "azurerm_monitor_private_link_scoped_service" "appi" {
  name                = "${var.app_insights_name}-ampls"
  resource_group_name = var.resource_group_name
  scope_name          = azurerm_monitor_private_link_scope.ampls.name
  linked_resource_id  = azurerm_application_insights.appi.id
}

############################################################
# Single private endpoint for the whole AMPLS.
#
# A single "azuremonitor" private endpoint front-ends every
# Azure Monitor data-plane endpoint (ingestion, query, live
# metrics, the global agent service and the AMPLS blob store).
# All five privatelink DNS zones must be supplied so the records
# land in the zones served by the hub DNS resolver.
############################################################
module "private_endpoint" {
  source                        = "../privateEndpoint"
  private_endpoint_name         = lower("${var.ampls_name}-pe-01")
  location                      = var.location
  resource_group_name           = var.resource_group_name
  subnet_id                     = var.private_endpoint_subnet_id
  custom_network_interface_name = lower("${var.ampls_name}-pe-01-nic")
  private_dns_zone_ids          = var.private_dns_zone_ids
  service_connection_name       = lower("${var.ampls_name}-pe-01")
  target_resource_id            = azurerm_monitor_private_link_scope.ampls.id
  subresource_names             = ["azuremonitor"]

  depends_on = [
    azurerm_monitor_private_link_scoped_service.law,
    azurerm_monitor_private_link_scoped_service.appi,
  ]
}
