variable "domain_ai" {
  description = "Domain name"
  type        = string
}

variable "location" {
  description = "The Azure location where the resource group will be created."
  type        = string
  default     = "germanywestcentral"
}

variable "location_short" {
  description = "Short Name Region"
  type        = string
  default     = "GWC"
}

variable "foundry_id" {
  description = "The ID of the Foundry resource"
  type        = string
}

variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "environment" {
  description = "The environment for the resource (e.g., dev, test, prod)."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group where dependent resources exist."
  type        = string
}

variable "storage_account_id" {
  description = "Storage account resource ID."
  type        = string
}

variable "storage_account_name" {
  description = "Storage account name."
  type        = string
}

variable "storage_primary_blob_endpoint" {
  description = "Primary blob endpoint for project storage connection."
  type        = string
}

variable "ai_search_id" {
  description = "Azure AI Search resource ID."
  type        = string
}

variable "ai_search_name" {
  description = "Azure AI Search service name."
  type        = string
}

variable "cosmosdb_account_id" {
  description = "Cosmos DB account resource ID."
  type        = string
}

variable "cosmosdb_account_name" {
  description = "Cosmos DB account name."
  type        = string
}

variable "cosmosdb_endpoint" {
  description = "Cosmos DB endpoint URL for project connection."
  type        = string
}

variable "enable_collection_level_roles" {
  description = "Whether to create collection-level Cosmos DB SQL role assignments and scoped storage role. Set to true after the foundry project has been applied at least once."
  type        = bool
  default     = false
}

variable "enable_app_insights_connection" {
  description = "Create an Application Insights connection on the project for agent tracing/monitoring."
  type        = bool
  default     = false
}

variable "app_insights_id" {
  description = "Application Insights component resource ID to connect to the project."
  type        = string
  default     = null
}

variable "app_insights_connection_string" {
  description = "Application Insights connection string used by the project connection."
  type        = string
  default     = null
  sensitive   = true
}
