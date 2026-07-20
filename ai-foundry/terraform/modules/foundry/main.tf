terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.100, < 5.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
  }
}

############################################################
# Locals
############################################################
locals {
  account_name        = coalesce(var.account_name_override, lower("${var.environment}-${var.location_short}-${var.project_name}-${var.domain_ai}-aif-01"))
  custom_subdomain    = local.account_name
  private_endpoint_id = lower("${local.account_name}-pe-01")

  # v2 (new) Foundry adds project management + agent network injection.
  # v1 falls back to a plain AI Services account.
  network_injections = var.foundry_v2 ? [
    {
      scenario                   = "agent"
      subnetArmId                = var.foundry_subnet_injection_id
      useMicrosoftManagedNetwork = false
    }
  ] : []
}

############################################################
# AI Foundry / AI Services account (private)
############################################################
resource "azapi_resource" "ai_foundry" {
  type                      = "Microsoft.CognitiveServices/accounts@2025-06-01"
  schema_validation_enabled = true
  name                      = local.account_name

  identity {
    type = "SystemAssigned"
  }

  location  = var.location
  parent_id = var.rg_id
  tags      = var.tags

  body = {
    kind = "AIServices"
    properties = {
      allowProjectManagement = var.foundry_v2
      customSubDomainName    = local.custom_subdomain
      publicNetworkAccess    = "Disabled"
      disableLocalAuth       = var.disable_local_auth

      # NetworkAcls are enforced only when publicNetworkAccess = "Enabled",
      # but setting an explicit Deny default is defense-in-depth in case
      # public access is ever toggled on out-of-band.
      networkAcls = {
        defaultAction       = var.network_acls_default_action
        bypass              = "AzureServices"
        virtualNetworkRules = []
        ipRules             = []
      }

      networkInjections = local.network_injections
    }
    sku = {
      name = var.foundry_sku
    }
  }

  lifecycle {
    ignore_changes = [tags]

    precondition {
      condition     = length(local.account_name) >= 2 && length(local.account_name) <= 64
      error_message = "Composed Cognitive Services account name '${local.account_name}' must be 2-64 characters. Shorten environment, location_short, project_name, or domain_ai."
    }

    precondition {
      condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", local.account_name))
      error_message = "Composed account name '${local.account_name}' must be lowercase alphanumerics/hyphens and not start or end with a hyphen."
    }
  }
}

############################################################
# Optional default model deployment
############################################################
resource "azurerm_cognitive_deployment" "aifoundry_model_deployment" {
  count = var.enable_default_model_deployment ? 1 : 0

  depends_on = [
    azapi_resource.ai_foundry,
  ]

  name                 = var.model_deployment_name
  cognitive_account_id = azapi_resource.ai_foundry.id

  sku {
    name     = var.model_sku_name
    capacity = var.model_capacity
  }

  model {
    format  = var.model_format
    name    = var.model_name
    version = var.model_version
  }
}

############################################################
# Wait for control-plane propagation before creating the PE
############################################################
resource "time_sleep" "wait_60_seconds" {
  depends_on      = [azapi_resource.ai_foundry]
  create_duration = "60s"
}

############################################################
# Private endpoint for the account
############################################################
module "private_endpoint_account_pe" {
  source                        = "../privateEndpoint"
  private_endpoint_name         = local.private_endpoint_id
  location                      = var.location
  resource_group_name           = var.rg_name
  subnet_id                     = var.foundry_subnet_id
  custom_network_interface_name = "${local.private_endpoint_id}-nic"
  private_dns_zone_ids = [
    var.private_dns_zone_id_cognitiveservices,
    var.private_dns_zone_id_openai,
    var.private_dns_zone_id_aiservices,
  ]
  service_connection_name = local.private_endpoint_id
  target_resource_id      = azapi_resource.ai_foundry.id
  subresource_names       = ["account"]

  depends_on = [time_sleep.wait_60_seconds]
}
