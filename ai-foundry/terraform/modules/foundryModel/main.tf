terraform {
  required_providers {
    azapi = {
      source = "Azure/azapi"
    }
    time = {
      source = "hashicorp/time"
    }
  }
}

## Pause 30 seconds before creating the deployment to avoid provisioning race conditions
resource "time_sleep" "wait_30_seconds" {
  create_duration = "30s"
}

## Create a deployment for OpenAI's GPT's in the AI Foundry resource
##
resource "azapi_resource" "aifoundry_deployment_gpt" {
  type      = "Microsoft.CognitiveServices/accounts/deployments@2023-05-01"
  name      = var.deployment_name
  parent_id = var.parent_id

  depends_on = [time_sleep.wait_30_seconds]

  body = {
    sku = {
      name     = var.sku_name
      capacity = var.capacity
    }
    properties = {
      model = {
        format  = "OpenAI"
        name    = var.model_name
        version = var.model_version
      }
    }
  }
}