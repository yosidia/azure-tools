variable "sa_name" {
  description = "The name of the Storage Account."
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group."
  type        = string
}

variable "location" {
  description = "The Azure region where the resource will be created."
  type        = string
}

variable "account_tier" {
  description = "Defines the Tier to use for this storage account (Standard or Premium)."
  type        = string
  default     = "Standard"
}

variable "account_replication_type" {
  description = "Defines the type of replication to use for this storage account (LRS, GRS, RAGRS, ZRS)."
  type        = string
  default     = "LRS"
}

variable "public_network_access_enabled" {
  description = "Specifies whether public network access is enabled for the storage account."
  type        = bool
  default     = false
}

variable "allow_nested_items_to_be_public" {
  description = "Specifies whether nested items like blobs can be made public."
  type        = bool
  default     = false
}

variable "tags" {
  description = "A map of tags to assign to the resource."
  type        = map(string)
  default     = {}
}

variable "pe_dfs_count" {
  description = "Number of DFS private endpoints to create (0 or 1)."
  type        = number
  default     = 0
}

variable "pe_blob_count" {
  description = "Number of blob private endpoints to create (0 or 1)."
  type        = number
  default     = 1
}

variable "pe_table_count" {
  description = "Number of table private endpoints to create (0 or 1)."
  type        = number
  default     = 0
}

variable "sa_subnet_id" {
  description = "The ID of the subnet to which the private endpoint will be connected."
  type        = string
}

variable "private_dns_zone_id_blob" {
  description = "Private DNS zone ID for privatelink.blob.core.windows.net."
  type        = string
}

variable "private_dns_zone_id_dfs" {
  description = "Private DNS zone ID for privatelink.dfs.core.windows.net. Only required when the DFS endpoint is enabled."
  type        = string
  default     = null
}

variable "private_dns_zone_id_table" {
  description = "Private DNS zone ID for privatelink.table.core.windows.net. Only required when the table endpoint is enabled."
  type        = string
  default     = null
}
