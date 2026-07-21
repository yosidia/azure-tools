variable "deployment_name" {
  description = "Name of the AI Foundry model deployment"
  type        = string
}

variable "model_version" {
  description = "Version of the model to deploy"
  type        = string
}

variable "parent_id" {
  description = "The resource ID of the parent AI Foundry account"
  type        = string
}

variable "model_name" {
  description = "Name of the model to deploy"
  type        = string
}

variable "capacity" {
  description = "SKU capacity for the model deployment"
  type        = number
  default     = 1
}

variable "sku_name" {
  description = "SKU name for the model deployment (e.g. GlobalStandard, Standard)"
  type        = string
  default     = "GlobalStandard"
}
