variable "location" {
  description = "The Azure location where the resource group will be created."
  type        = string
}

variable "rg_name" {
  description = "RG Name"
  type        = string
}

variable "environment" {
  description = "Environment"
  type        = string
}

variable "project_name" {
  description = "Project Name."
  type        = string
}

variable "location_short" {
  description = "Short code for the location"
  type        = string
}

variable "rg_id" {
  description = "ID of parent resource group"
  type        = string
}

variable "foundry_subnet_id" {
  description = "Subnet ID for the AI Foundry account private endpoint."
  type        = string
}

variable "domain_ai" {
  description = "Domain name token used in the Foundry account name."
  type        = string
}

variable "account_name_override" {
  description = "Explicit AI Foundry account name. When null, the name is derived from environment/location_short/project_name/domain_ai."
  type        = string
  default     = null
}

variable "network_acls_default_action" {
  description = "Default action for the account network ACLs (Allow or Deny)."
  type        = string
  default     = "Deny"

  validation {
    condition     = contains(["Allow", "Deny"], var.network_acls_default_action)
    error_message = "network_acls_default_action must be Allow or Deny."
  }
}

variable "foundry_subnet_injection_id" {
  description = "Subnet ID for AI Foundry agent network injection (v2 only)."
  type        = string
  default     = null
}

############################################################
# Foundry deployment shape
############################################################
variable "foundry_v2" {
  description = <<EOT
Deploy the new (v2) Azure AI Foundry account shape:
  - allowProjectManagement = true (enables Foundry projects as child resources)
  - networkInjections with scenario "agent" using foundry_subnet_injection_id

Set to false to deploy a plain AI Services account (no project management, no
agent network injection). Default: true.
EOT
  type        = bool
  default     = true

  validation {
    condition     = !var.foundry_v2 || var.foundry_subnet_injection_id != null
    error_message = "foundry_subnet_injection_id must be provided when foundry_v2 = true."
  }
}

variable "foundry_sku" {
  description = "SKU name for the AI Foundry / Cognitive Services account."
  type        = string
  default     = "S0"

  validation {
    condition     = contains(["S0", "F0"], var.foundry_sku)
    error_message = "foundry_sku must be one of: S0, F0."
  }
}

variable "disable_local_auth" {
  description = "Disable local (key) auth and require Entra ID for data-plane calls."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to the AI Foundry account."
  type        = map(string)
  default     = {}
}

############################################################
# Optional default model deployment
############################################################
variable "enable_default_model_deployment" {
  description = "Whether to deploy a default model deployment on the AI Foundry account."
  type        = bool
  default     = true
}

variable "model_deployment_name" {
  description = "Model deployment name in Azure AI Foundry account."
  type        = string
  default     = "gpt-4o"
}

variable "model_name" {
  description = "Model name for the default deployment."
  type        = string
  default     = "gpt-4o"
}

variable "model_format" {
  description = "Model format for the default deployment."
  type        = string
  default     = "OpenAI"
}

variable "model_version" {
  description = "Model version for the default deployment."
  type        = string
  default     = "2024-11-20"
}

variable "model_sku_name" {
  description = "Model deployment SKU name."
  type        = string
  default     = "GlobalStandard"
}

variable "model_capacity" {
  description = "Model deployment capacity."
  type        = number
  default     = 1
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
