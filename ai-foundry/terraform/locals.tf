############################################################
# Local values
#
# Input values come from native Terraform variables (see variables.tf
# and terraform.tfvars). Derived names fall back to a naming convention
# unless an explicit *_override / *_name variable is provided.
############################################################
locals {
  # Core / naming
  location            = var.location
  location_short      = var.location_short
  environment         = var.environment
  environment_tag     = var.environment_tag
  project_name        = var.project_name
  domain_ai           = var.domain_ai
  domain_correctors   = var.domain_correctors
  resource_group_name = var.resource_group_name

  # Tagging / ownership
  application_name  = var.application_name
  application_owner = var.application_owner

  # Networking
  foundry_subnet_id           = var.foundry_subnet_id
  foundry_subnet_injection_id = var.foundry_subnet_injection_id

  # Private DNS zones
  private_dns_zone_id_cognitiveservices = var.private_dns_zone_id_cognitiveservices
  private_dns_zone_id_openai            = var.private_dns_zone_id_openai
  private_dns_zone_id_aiservices        = var.private_dns_zone_id_aiservices
  private_dns_zone_id_search            = var.private_dns_zone_id_search
  private_dns_zone_id_cosmos_sql        = var.private_dns_zone_id_cosmos_sql
  private_dns_zone_id_storage_blob      = var.private_dns_zone_id_storage_blob
  private_dns_zone_id_storage_dfs       = var.private_dns_zone_id_storage_dfs
  private_dns_zone_id_storage_table     = var.private_dns_zone_id_storage_table

  # Azure Monitor private DNS zones (for AMPLS private endpoint)
  private_dns_zone_id_monitor  = var.private_dns_zone_id_monitor
  private_dns_zone_id_oms      = var.private_dns_zone_id_oms
  private_dns_zone_id_ods      = var.private_dns_zone_id_ods
  private_dns_zone_id_agentsvc = var.private_dns_zone_id_agentsvc

  # Service options
  ai_search_service_sku         = var.ai_search_service_sku
  enable_collection_level_roles = var.enable_collection_level_roles
  foundry_v2                    = var.foundry_v2

  ############################################################
  # Derived names (used when no explicit override is supplied)
  ############################################################
  base_name = lower("${local.environment}-${local.location_short}-${local.project_name}-${local.domain_ai}")

  ai_search_name        = coalesce(var.ai_search_name_override, lower("${replace(local.base_name, "-", "")}srch${random_string.suffix.result}"))
  cosmosdb_account_name = coalesce(var.cosmosdb_account_name_override, lower("${replace(local.base_name, "-", "")}cdb${random_string.suffix.result}"))
  storage_account_name  = coalesce(var.storage_account_name_override, substr(lower("${replace(local.base_name, "-", "")}st${random_string.suffix.result}"), 0, 24))

  # Default AI Foundry project name
  foundry_project_name = coalesce(var.foundry_project_name, lower("${local.environment}-${local.location_short}-${local.project_name}-${local.domain_correctors}-aip"))

  # Monitoring resource names
  log_analytics_workspace_name = lower("${local.base_name}-law")
  app_insights_name            = lower("${local.base_name}-appi")
  ampls_name                   = lower("${local.base_name}-ampls")
}
