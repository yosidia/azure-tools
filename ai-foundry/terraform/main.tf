############################################################
# Resource group
############################################################
resource "azurerm_resource_group" "ai" {
  name     = local.resource_group_name
  location = local.location

  tags = {
    application       = local.application_name
    application_owner = local.application_owner
    environment       = local.environment_tag
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

############################################################
# Naming suffix
############################################################
resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
  numeric = true
}

############################################################
# Monitoring: private Application Insights + Log Analytics
# behind a single Azure Monitor Private Link Scope (AMPLS)
#
# Declared early because Cosmos DB (diagnostic settings) and
# the default Foundry project (App Insights connection) both
# depend on it.
############################################################
module "monitoring" {
  source = "./modules/monitoring"

  resource_group_name = azurerm_resource_group.ai.name
  location            = local.location

  workspace_name    = local.log_analytics_workspace_name
  app_insights_name = local.app_insights_name
  ampls_name        = local.ampls_name

  public_network_access_enabled = false
  ampls_ingestion_access_mode   = "PrivateOnly"
  ampls_query_access_mode       = "PrivateOnly"

  private_endpoint_subnet_id = local.foundry_subnet_id
  private_dns_zone_ids = [
    local.private_dns_zone_id_monitor,
    local.private_dns_zone_id_oms,
    local.private_dns_zone_id_ods,
    local.private_dns_zone_id_agentsvc,
    local.private_dns_zone_id_storage_blob,
  ]

  tags = {
    application       = local.application_name
    application_owner = local.application_owner
    environment       = local.environment_tag
  }

  depends_on = [azurerm_resource_group.ai]
}

############################################################
# Storage account (private)
############################################################
module "storage_account" {
  source = "./modules/storageaccount"

  sa_name                  = local.storage_account_name
  resource_group_name      = azurerm_resource_group.ai.name
  location                 = local.location
  sa_subnet_id             = local.foundry_subnet_id
  account_replication_type = var.storage_account_replication_type

  pe_blob_count  = 1
  pe_dfs_count   = var.enable_storage_dfs_endpoint ? 1 : 0
  pe_table_count = var.enable_storage_table_endpoint ? 1 : 0

  private_dns_zone_id_blob  = local.private_dns_zone_id_storage_blob
  private_dns_zone_id_dfs   = local.private_dns_zone_id_storage_dfs
  private_dns_zone_id_table = local.private_dns_zone_id_storage_table

  depends_on = [azurerm_resource_group.ai]
}

############################################################
# AI Foundry account (private, network-injected)
############################################################
module "ai_services" {
  source = "./modules/foundry"

  location                        = local.location
  rg_name                         = azurerm_resource_group.ai.name
  rg_id                           = azurerm_resource_group.ai.id
  environment                     = local.environment
  location_short                  = local.location_short
  domain_ai                       = local.domain_ai
  project_name                    = local.project_name
  account_name_override           = var.foundry_account_name
  network_acls_default_action     = var.foundry_network_acls_default_action
  foundry_subnet_id               = local.foundry_subnet_id
  foundry_subnet_injection_id     = local.foundry_subnet_injection_id
  foundry_v2                      = local.foundry_v2
  enable_default_model_deployment = false

  tags = {
    application       = local.application_name
    application_owner = local.application_owner
    environment       = local.environment_tag
  }

  private_dns_zone_id_cognitiveservices = local.private_dns_zone_id_cognitiveservices
  private_dns_zone_id_openai            = local.private_dns_zone_id_openai
  private_dns_zone_id_aiservices        = local.private_dns_zone_id_aiservices

  depends_on = [azurerm_resource_group.ai]
}

############################################################
# Azure AI Search (private)
############################################################
module "ai_search_service_ai" {
  source = "./modules/aisearch"

  search_service_name           = local.ai_search_name
  resource_group_name           = azurerm_resource_group.ai.name
  location                      = local.location
  sku                           = local.ai_search_service_sku
  identity_type                 = "SystemAssigned"
  public_network_access_enabled = false
  ais_subnet_id                 = local.foundry_subnet_id
  private_dns_zone_ids          = [local.private_dns_zone_id_search]

  tags = {
    application       = local.application_name
    application_owner = local.application_owner
    environment       = local.environment_tag
  }

  depends_on = [azurerm_resource_group.ai]
}

############################################################
# Cosmos DB (private)
############################################################
module "cosmosdb_ai" {
  source = "./modules/cosmosDB"

  account_name               = local.cosmosdb_account_name
  resource_group_name        = azurerm_resource_group.ai.name
  location                   = local.location
  private_endpoint_subnet_id = local.foundry_subnet_id
  private_dns_zone_ids       = [local.private_dns_zone_id_cosmos_sql]
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id

  depends_on = [azurerm_resource_group.ai, module.monitoring]
}

############################################################
# Firewall / NSG rules: allow agents to stream logs to the
# Azure Monitor private endpoint.
#
# Intra-VNet 443 is already permitted by the default
# AllowVnetInBound/OutBound rules, but these explicit rules
# document and guarantee the private log path.
############################################################
resource "azurerm_network_security_rule" "agent_to_monitor_pe" {
  count = var.manage_agent_log_nsg_rules ? 1 : 0

  name                        = "Allow-Agent-To-AzureMonitor-PE-443"
  priority                    = 200
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = var.agent_subnet_address_prefix
  destination_address_prefix  = var.pe_subnet_address_prefix
  resource_group_name         = var.agent_subnet_nsg_resource_group_name
  network_security_group_name = var.agent_subnet_nsg_name
}

resource "azurerm_network_security_rule" "agent_to_dns" {
  count = var.manage_agent_log_nsg_rules && var.dns_resolver_ip != null ? 1 : 0

  name                        = "Allow-Agent-To-DNS-Resolver-53"
  priority                    = 210
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_ranges     = ["53"]
  source_address_prefix       = var.agent_subnet_address_prefix
  destination_address_prefix  = "${var.dns_resolver_ip}/32"
  resource_group_name         = var.agent_subnet_nsg_resource_group_name
  network_security_group_name = var.agent_subnet_nsg_name
}

resource "azurerm_network_security_rule" "monitor_pe_inbound_from_agent" {
  count = var.manage_agent_log_nsg_rules ? 1 : 0

  name                        = "Allow-Agent-To-AzureMonitor-PE-443"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = var.agent_subnet_address_prefix
  destination_address_prefix  = var.pe_subnet_address_prefix
  resource_group_name         = var.pe_subnet_nsg_resource_group_name
  network_security_group_name = var.pe_subnet_nsg_name
}

############################################################
# Default AI Foundry project + connections + capability host
############################################################
module "foundry_project_default" {
  source = "./modules/foundryProject"

  location                      = local.location
  domain_ai                     = local.domain_ai
  environment                   = local.environment
  project_name                  = local.foundry_project_name
  foundry_id                    = module.ai_services.foundry_id
  resource_group_name           = azurerm_resource_group.ai.name
  storage_account_id            = module.storage_account.storage_account_id
  storage_account_name          = module.storage_account.storage_account_name
  storage_primary_blob_endpoint = module.storage_account.primary_blob_endpoint
  ai_search_id                  = module.ai_search_service_ai.search_service_id
  ai_search_name                = module.ai_search_service_ai.search_service_name
  cosmosdb_account_id           = module.cosmosdb_ai.cosmosdb_id
  cosmosdb_account_name         = module.cosmosdb_ai.cosmosdb_name
  cosmosdb_endpoint             = module.cosmosdb_ai.cosmosdb_endpoint
  enable_collection_level_roles = local.enable_collection_level_roles

  enable_app_insights_connection = true
  app_insights_id                = module.monitoring.app_insights_id
  app_insights_connection_string = module.monitoring.app_insights_connection_string

  depends_on = [
    module.ai_services,
    module.storage_account,
    module.ai_search_service_ai,
    module.cosmosdb_ai,
    module.monitoring,
  ]
}
