variable "resource_group_name" {
  description = "Resource group hosting the monitoring stack."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "workspace_name" {
  description = "Log Analytics workspace name."
  type        = string
}

variable "workspace_sku" {
  description = "Log Analytics workspace SKU."
  type        = string
  default     = "PerGB2018"
}

variable "workspace_retention_in_days" {
  description = "Log Analytics workspace data retention in days."
  type        = number
  default     = 30
}

variable "app_insights_name" {
  description = "Application Insights component name."
  type        = string
}

variable "app_insights_application_type" {
  description = "Application Insights application type."
  type        = string
  default     = "web"
}

variable "public_network_access_enabled" {
  description = "Allow public ingestion/query on the workspace and Application Insights. Keep false so telemetry only flows over Private Link."
  type        = bool
  default     = false
}

variable "ampls_name" {
  description = "Azure Monitor Private Link Scope (AMPLS) name."
  type        = string
}

variable "ampls_ingestion_access_mode" {
  description = "AMPLS ingestion access mode (Open or PrivateOnly)."
  type        = string
  default     = "PrivateOnly"

  validation {
    condition     = contains(["Open", "PrivateOnly"], var.ampls_ingestion_access_mode)
    error_message = "ampls_ingestion_access_mode must be Open or PrivateOnly."
  }
}

variable "ampls_query_access_mode" {
  description = "AMPLS query access mode (Open or PrivateOnly)."
  type        = string
  default     = "PrivateOnly"

  validation {
    condition     = contains(["Open", "PrivateOnly"], var.ampls_query_access_mode)
    error_message = "ampls_query_access_mode must be Open or PrivateOnly."
  }
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID for the AMPLS private endpoint."
  type        = string
}

variable "private_dns_zone_ids" {
  description = <<EOT
Private DNS zone IDs for the Azure Monitor private endpoint. Provide all five:
  - privatelink.monitor.azure.com
  - privatelink.oms.opinsights.azure.com
  - privatelink.ods.opinsights.azure.com
  - privatelink.agentsvc.azure-automation.net
  - privatelink.blob.core.windows.net
EOT
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply to the monitoring resources."
  type        = map(string)
  default     = {}
}
