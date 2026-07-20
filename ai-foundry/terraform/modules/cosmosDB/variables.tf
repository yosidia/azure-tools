variable "account_name" {
  description = "Cosmos DB account name"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure location"
  type        = string
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID for the Cosmos DB private endpoint"
  type        = string
}

variable "private_dns_zone_ids" {
  description = "Private DNS zone IDs for the Cosmos DB SQL private endpoint (privatelink.documents.azure.com)."
  type        = list(string)
}

############################################################
# Cosmos DB account configuration
############################################################
variable "offer_type" {
  description = "Cosmos DB offer type."
  type        = string
  default     = "Standard"
}

variable "kind" {
  description = "Cosmos DB account kind."
  type        = string
  default     = "GlobalDocumentDB"
}

variable "free_tier_enabled" {
  description = "Enable the Cosmos DB free tier."
  type        = bool
  default     = false
}

variable "local_authentication_disabled" {
  description = "Disable local (key) authentication and require Entra ID."
  type        = bool
  default     = true
}

variable "public_network_access_enabled" {
  description = "Enable public network access to the Cosmos DB account."
  type        = bool
  default     = false
}

variable "automatic_failover_enabled" {
  description = "Enable automatic failover."
  type        = bool
  default     = false
}

variable "multiple_write_locations_enabled" {
  description = "Enable multiple write locations."
  type        = bool
  default     = false
}

variable "consistency_level" {
  description = "Default consistency level."
  type        = string
  default     = "Session"
}

variable "failover_priority" {
  description = "Failover priority for the geo location."
  type        = number
  default     = 0
}

variable "zone_redundant" {
  description = "Whether the geo location is zone redundant."
  type        = bool
  default     = false
}

variable "private_endpoint_suffix" {
  description = "Suffix appended to the account name to form the private endpoint name."
  type        = string
  default     = "pe-01"
}

variable "subresource_names" {
  description = "Subresource names (groupIds) targeted by the Cosmos DB private endpoint."
  type        = list(string)
  default     = ["Sql"]
}

############################################################
# Diagnostic settings
############################################################
variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID to send Cosmos DB diagnostics to. When null, no diagnostic setting is created."
  type        = string
  default     = null
}

variable "diagnostic_setting_name" {
  description = "Name of the Cosmos DB diagnostic setting."
  type        = string
  default     = "diag"
}
