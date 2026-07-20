variable "private_endpoint_name" {
  type        = string
  description = "Name of the private endpoint"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name"
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID for the private endpoint"
}

variable "custom_network_interface_name" {
  type        = string
  description = "Custom network interface name"
}

variable "dns_zone_group_name" {
  type        = string
  default     = "default"
  description = "DNS zone group name"
}

variable "private_dns_zone_ids" {
  type        = list(string)
  description = "List of private DNS zone IDs"
}

variable "service_connection_name" {
  type        = string
  description = "Name of the private service connection"
}

variable "target_resource_id" {
  type        = string
  description = "Target resource ID for the private endpoint"
}

variable "is_manual_connection" {
  type        = bool
  default     = false
  description = "Is manual connection"
}

variable "subresource_names" {
  type        = list(string)
  description = "List of subresource names"
}

