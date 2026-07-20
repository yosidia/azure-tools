############################################################
# Core / naming
############################################################
variable "location" {
  description = "Azure region for the AI Foundry stack."
  type        = string
}

variable "location_short" {
  description = "Short code for the location, used in derived names."
  type        = string
}

variable "environment" {
  description = "Environment token used in derived names (e.g. dev, prod)."
  type        = string
}

variable "environment_tag" {
  description = "Environment value used for the 'environment' tag."
  type        = string
}

variable "project_name" {
  description = "Project token used in derived names."
  type        = string
}

variable "domain_ai" {
  description = "Domain token used in derived names."
  type        = string
}

variable "domain_correctors" {
  description = "Domain token used when composing the default project name."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group hosting the AI Foundry stack."
  type        = string
}

############################################################
# Explicit resource-name overrides
#
# When set, these take precedence over the derived names so the
# configuration matches an existing deployment exactly. Leave null
# to fall back to the derived naming convention.
############################################################
variable "foundry_account_name" {
  description = "Explicit AI Foundry / Cognitive Services account name. When null, the name is derived from the naming convention."
  type        = string
  default     = null
}

variable "foundry_project_name" {
  description = "Explicit default AI Foundry project name. When null, the name is derived from the naming convention."
  type        = string
  default     = null
}

variable "storage_account_name_override" {
  description = "Explicit storage account name. When null, the name is derived from the naming convention."
  type        = string
  default     = null
}

variable "cosmosdb_account_name_override" {
  description = "Explicit Cosmos DB account name. When null, the name is derived from the naming convention."
  type        = string
  default     = null
}

variable "ai_search_name_override" {
  description = "Explicit Azure AI Search service name. When null, the name is derived from the naming convention."
  type        = string
  default     = null
}

############################################################
# Tagging / ownership
############################################################
variable "application_name" {
  description = "Value for the 'application' tag."
  type        = string
  default     = ""
}

variable "application_owner" {
  description = "Value for the 'application_owner' tag."
  type        = string
  default     = ""
}

############################################################
# Networking
############################################################
variable "foundry_subnet_id" {
  description = "Subnet ID used for all private endpoints in the stack."
  type        = string
}

variable "foundry_subnet_injection_id" {
  description = "Subnet ID for AI Foundry agent network injection (v2 only)."
  type        = string
}

############################################################
# Private DNS zones
############################################################
variable "private_dns_zone_id_cognitiveservices" {
  description = "Private DNS zone ID for privatelink.cognitiveservices.azure.com."
  type        = string
}

variable "private_dns_zone_id_openai" {
  description = "Private DNS zone ID for privatelink.openai.azure.com."
  type        = string
}

variable "private_dns_zone_id_aiservices" {
  description = "Private DNS zone ID for privatelink.services.ai.azure.com."
  type        = string
}

variable "private_dns_zone_id_search" {
  description = "Private DNS zone ID for privatelink.search.windows.net."
  type        = string
}

variable "private_dns_zone_id_cosmos_sql" {
  description = "Private DNS zone ID for privatelink.documents.azure.com."
  type        = string
}

variable "private_dns_zone_id_storage_blob" {
  description = "Private DNS zone ID for privatelink.blob.core.windows.net."
  type        = string
}

variable "private_dns_zone_id_monitor" {
  description = "Private DNS zone ID for privatelink.monitor.azure.com (Azure Monitor / Application Insights)."
  type        = string
}

variable "private_dns_zone_id_oms" {
  description = "Private DNS zone ID for privatelink.oms.opinsights.azure.com (Log Analytics agent)."
  type        = string
}

variable "private_dns_zone_id_ods" {
  description = "Private DNS zone ID for privatelink.ods.opinsights.azure.com (Log Analytics ingestion)."
  type        = string
}

variable "private_dns_zone_id_agentsvc" {
  description = "Private DNS zone ID for privatelink.agentsvc.azure-automation.net (Log Analytics agent service)."
  type        = string
}

variable "private_dns_zone_id_storage_dfs" {
  description = "Private DNS zone ID for privatelink.dfs.core.windows.net. Only required when the DFS endpoint is enabled."
  type        = string
  default     = null
}

variable "private_dns_zone_id_storage_table" {
  description = "Private DNS zone ID for privatelink.table.core.windows.net. Only required when the table endpoint is enabled."
  type        = string
  default     = null
}

############################################################
# Service options
############################################################
variable "ai_search_service_sku" {
  description = "SKU tier for the Azure AI Search service."
  type        = string
  default     = "basic"
}

variable "storage_account_replication_type" {
  description = "Replication type for the storage account (LRS, ZRS, GRS, RAGRS)."
  type        = string
  default     = "ZRS"
}

variable "enable_storage_dfs_endpoint" {
  description = "Create a DFS private endpoint for the storage account."
  type        = bool
  default     = false
}

variable "enable_storage_table_endpoint" {
  description = "Create a table private endpoint for the storage account."
  type        = bool
  default     = false
}

variable "foundry_network_acls_default_action" {
  description = "Default action for the AI Foundry account network ACLs (Allow or Deny)."
  type        = string
  default     = "Allow"

  validation {
    condition     = contains(["Allow", "Deny"], var.foundry_network_acls_default_action)
    error_message = "foundry_network_acls_default_action must be Allow or Deny."
  }
}

variable "enable_collection_level_roles" {
  description = "Assign collection-level Cosmos DB data-plane roles for the project identity."
  type        = bool
  default     = false
}

variable "foundry_v2" {
  description = "Deploy the v2 AI Foundry account shape (project management + agent network injection)."
  type        = bool
  default     = true
}

############################################################
# Firewall / NSG rules for private log streaming
############################################################
variable "manage_agent_log_nsg_rules" {
  description = "Create explicit NSG allow rules so agents can reach the Azure Monitor private endpoint (443) and the DNS resolver (53)."
  type        = bool
  default     = true
}

variable "agent_subnet_nsg_name" {
  description = "Name of the NSG attached to the agent (network injection) subnet."
  type        = string
  default     = null
}

variable "agent_subnet_nsg_resource_group_name" {
  description = "Resource group of the agent subnet NSG."
  type        = string
  default     = null
}

variable "pe_subnet_nsg_name" {
  description = "Name of the NSG attached to the private endpoint subnet."
  type        = string
  default     = null
}

variable "pe_subnet_nsg_resource_group_name" {
  description = "Resource group of the private endpoint subnet NSG."
  type        = string
  default     = null
}

variable "agent_subnet_address_prefix" {
  description = "Address prefix of the agent (network injection) subnet."
  type        = string
  default     = null
}

variable "pe_subnet_address_prefix" {
  description = "Address prefix of the private endpoint subnet."
  type        = string
  default     = null
}

variable "dns_resolver_ip" {
  description = "IP address of the DNS resolver used by the spoke VNet (for the DNS allow rule)."
  type        = string
  default     = null
}
