variable "search_service_name" {
  description = "The name of the Azure AI Search service."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group hosting the Azure AI Search service."
  type        = string
}

variable "location" {
  description = "Azure region for the service."
  type        = string
}

variable "sku" {
  description = "SKU tier for the Azure AI Search service."
  type        = string
  default     = "standard"
}

variable "replica_count" {
  description = "Number of replicas configured for the service."
  type        = number
  default     = 1
}

variable "partition_count" {
  description = "Number of partitions configured for the service."
  type        = number
  default     = 1
}

variable "public_network_access_enabled" {
  description = "Controls whether the Azure AI Search service allows public network access."
  type        = bool
  default     = false
}

variable "identity_type" {
  description = "Managed identity type for the service (SystemAssigned or None)."
  type        = string
  default     = "SystemAssigned"
}

variable "tags" {
  description = "Tags to apply to the Azure AI Search service."
  type        = map(string)
  default     = {}
}

variable "private_dns_zone_ids" {
  description = "List of private DNS zone IDs for the Azure AI Search service private endpoint."
  type        = list(string)
}
variable "ais_subnet_id" {
  description = "Subnet ID for the Azure AI Search service private endpoint."
  type        = string
}