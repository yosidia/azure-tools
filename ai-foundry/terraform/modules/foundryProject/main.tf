terraform {
  required_providers {
    azapi = {
      source = "Azure/azapi"
    }
  }
}

resource "azapi_resource" "foundry_project" {
  type                      = "Microsoft.CognitiveServices/accounts/projects@2025-06-01"
  name                      = lower(var.project_name)
  location                  = var.location
  parent_id                 = var.foundry_id
  schema_validation_enabled = false

  body = {
    sku = {
      name = "S0"
    }
    identity = {
      type = "SystemAssigned"
    }
    properties = {
      description = "AI Foundry Project for ${var.project_name}"
      displayName = var.project_name
    }
  }

  response_export_values = [
    "identity.principalId",
    "properties.internalId"
  ]

  lifecycle {
    ignore_changes = all
  }
}

resource "time_sleep" "wait_project_identities" {
  depends_on = [
    azapi_resource.foundry_project
  ]
  create_duration = "10s"
}

locals {
  connection_name_suffix      = substr(md5(lower(var.project_name)), 0, 8)
  cosmos_connection_name      = lower("${var.cosmosdb_account_name}-${local.connection_name_suffix}")
  storage_connection_name     = lower("${var.storage_account_name}-${local.connection_name_suffix}")
  search_connection_name      = lower("${var.ai_search_name}-${local.connection_name_suffix}")
  appinsights_connection_name = lower("appinsights-${local.connection_name_suffix}")
}

resource "azapi_resource" "conn_cosmosdb" {
  type                      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01"
  name                      = local.cosmos_connection_name
  parent_id                 = azapi_resource.foundry_project.id
  schema_validation_enabled = false

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    azapi_resource.foundry_project
  ]

  body = {
    name = local.cosmos_connection_name
    properties = {
      category = "CosmosDb"
      target   = var.cosmosdb_endpoint
      authType = "AAD"
      metadata = {
        ApiType    = "Azure"
        ResourceId = var.cosmosdb_account_id
        location   = var.location
      }
    }
  }
}

resource "azapi_resource" "conn_storage" {
  type                      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01"
  name                      = local.storage_connection_name
  parent_id                 = azapi_resource.foundry_project.id
  schema_validation_enabled = false

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    azapi_resource.foundry_project
  ]

  body = {
    name = local.storage_connection_name
    properties = {
      category = "AzureStorageAccount"
      target   = var.storage_primary_blob_endpoint
      authType = "AAD"
      metadata = {
        ApiType    = "Azure"
        ResourceId = var.storage_account_id
        location   = var.location
      }
    }
  }

  response_export_values = [
    "identity.principalId"
  ]
}

resource "azapi_resource" "conn_aisearch" {
  type                      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01"
  name                      = local.search_connection_name
  parent_id                 = azapi_resource.foundry_project.id
  schema_validation_enabled = false

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    azapi_resource.foundry_project
  ]

  body = {
    name = local.search_connection_name
    properties = {
      category = "CognitiveSearch"
      target   = "https://${var.ai_search_name}.search.windows.net"
      authType = "AAD"
      metadata = {
        ApiType    = "Azure"
        ApiVersion = "2025-05-01-preview"
        ResourceId = var.ai_search_id
        location   = var.location
      }
    }
  }

  response_export_values = [
    "identity.principalId"
  ]
}

############################################################
# Application Insights connection (agent tracing / monitoring)
#
# The connection target is the App Insights resource that is
# brought into the AMPLS, so all telemetry from agents in this
# project flows to the private Application Insights endpoint.
############################################################
resource "azapi_resource" "conn_appinsights" {
  count                     = var.enable_app_insights_connection ? 1 : 0
  type                      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01"
  name                      = local.appinsights_connection_name
  parent_id                 = azapi_resource.foundry_project.id
  schema_validation_enabled = false

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    azapi_resource.foundry_project
  ]

  body = {
    name = local.appinsights_connection_name
    properties = {
      category = "AppInsights"
      target   = var.app_insights_id
      authType = "ApiKey"
      credentials = {
        key = var.app_insights_connection_string
      }
      metadata = {
        ApiType    = "Azure"
        ResourceId = var.app_insights_id
        location   = var.location
      }
    }
  }
}

resource "azurerm_role_assignment" "cosmosdb_operator_ai_foundry_project" {
  depends_on = [
    time_sleep.wait_project_identities
  ]
  name                 = uuidv5("dns", "${azapi_resource.foundry_project.name}${azapi_resource.foundry_project.output.identity.principalId}${var.cosmosdb_account_name}cosmosdboperator")
  scope                = var.cosmosdb_account_id
  role_definition_name = "Cosmos DB Operator"
  principal_id         = azapi_resource.foundry_project.output.identity.principalId
}

resource "azurerm_cosmosdb_sql_role_assignment" "cosmosdb_builtin_data_contributor_ai_foundry_project" {
  depends_on = [
    time_sleep.wait_project_identities
  ]
  name                = uuidv5("dns", "${azapi_resource.foundry_project.name}${azapi_resource.foundry_project.output.identity.principalId}${var.cosmosdb_account_name}cosmosdbbuiltindatacontributor")
  resource_group_name = var.resource_group_name
  account_name        = var.cosmosdb_account_name
  scope               = var.cosmosdb_account_id
  role_definition_id  = "${var.cosmosdb_account_id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = azapi_resource.foundry_project.output.identity.principalId
}

resource "azurerm_role_assignment" "storage_blob_data_contributor_ai_foundry_project" {
  depends_on = [
    time_sleep.wait_project_identities
  ]
  name                 = uuidv5("dns", "${azapi_resource.foundry_project.name}${azapi_resource.foundry_project.output.identity.principalId}${var.storage_account_name}storageblobdatacontributor")
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azapi_resource.foundry_project.output.identity.principalId
}

resource "azurerm_role_assignment" "search_index_data_contributor_ai_foundry_project" {
  depends_on = [
    time_sleep.wait_project_identities
  ]
  name                 = uuidv5("dns", "${azapi_resource.foundry_project.name}${azapi_resource.foundry_project.output.identity.principalId}${var.ai_search_name}searchindexdatacontributor")
  scope                = var.ai_search_id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = azapi_resource.foundry_project.output.identity.principalId
}

resource "azurerm_role_assignment" "search_service_contributor_ai_foundry_project" {
  depends_on = [
    time_sleep.wait_project_identities
  ]
  name                 = uuidv5("dns", "${azapi_resource.foundry_project.name}${azapi_resource.foundry_project.output.identity.principalId}${var.ai_search_name}searchservicecontributor")
  scope                = var.ai_search_id
  role_definition_name = "Search Service Contributor"
  principal_id         = azapi_resource.foundry_project.output.identity.principalId
}

resource "time_sleep" "wait_rbac" {
  depends_on = [
    azurerm_role_assignment.cosmosdb_operator_ai_foundry_project,
    azurerm_cosmosdb_sql_role_assignment.cosmosdb_builtin_data_contributor_ai_foundry_project,
    azurerm_role_assignment.storage_blob_data_contributor_ai_foundry_project,
    azurerm_role_assignment.search_index_data_contributor_ai_foundry_project,
    azurerm_role_assignment.search_service_contributor_ai_foundry_project
  ]
  create_duration = "180s"
}

resource "azapi_resource" "foundry_project_capability_host" {
  type                      = "Microsoft.CognitiveServices/accounts/projects/capabilityHosts@2025-04-01-preview"
  name                      = "caphostproj"
  parent_id                 = azapi_resource.foundry_project.id
  schema_validation_enabled = false

  lifecycle {
    replace_triggered_by = [
      azapi_resource.conn_aisearch,
      azapi_resource.conn_cosmosdb,
      azapi_resource.conn_storage
    ]
  }

  depends_on = [
    azapi_resource.conn_aisearch,
    azapi_resource.conn_cosmosdb,
    azapi_resource.conn_storage,
    time_sleep.wait_rbac
  ]

  body = {
    properties = {
      capabilityHostKind = "Agents"
      vectorStoreConnections = [
        local.search_connection_name
      ]
      storageConnections = [
        local.storage_connection_name
      ]
      threadStorageConnections = [
        local.cosmos_connection_name
      ]
    }
  }
}

locals {
  foundry_project_internal_id = can(azapi_resource.foundry_project.output.properties.internalId) ? azapi_resource.foundry_project.output.properties.internalId : (can(azapi_resource.foundry_project.output["properties.internalId"]) ? azapi_resource.foundry_project.output["properties.internalId"] : (can(azapi_resource.foundry_project.output.internalId) ? azapi_resource.foundry_project.output.internalId : null))

  project_id_guid = local.foundry_project_internal_id != null && length(local.foundry_project_internal_id) >= 32 ? "${substr(local.foundry_project_internal_id, 0, 8)}-${substr(local.foundry_project_internal_id, 8, 4)}-${substr(local.foundry_project_internal_id, 12, 4)}-${substr(local.foundry_project_internal_id, 16, 4)}-${substr(local.foundry_project_internal_id, 20, 12)}" : null
}

resource "azurerm_cosmosdb_sql_role_assignment" "cosmosdb_db_sql_role_aifp_user_thread_message_store" {
  count = var.enable_collection_level_roles ? 1 : 0

  depends_on = [
    azapi_resource.foundry_project_capability_host
  ]
  name                = uuidv5("dns", "${azapi_resource.foundry_project.name}${azapi_resource.foundry_project.output.identity.principalId}userthreadmessage_dbsqlrole")
  resource_group_name = var.resource_group_name
  account_name        = var.cosmosdb_account_name
  scope               = "${var.cosmosdb_account_id}/dbs/enterprise_memory/colls/${local.project_id_guid}-thread-message-store"
  role_definition_id  = "${var.cosmosdb_account_id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = azapi_resource.foundry_project.output.identity.principalId
}

resource "azurerm_cosmosdb_sql_role_assignment" "cosmosdb_db_sql_role_aifp_system_thread_name" {
  count = var.enable_collection_level_roles ? 1 : 0

  depends_on = [
    azapi_resource.foundry_project_capability_host
  ]
  name                = uuidv5("dns", "${azapi_resource.foundry_project.name}${azapi_resource.foundry_project.output.identity.principalId}systemthread_dbsqlrole")
  resource_group_name = var.resource_group_name
  account_name        = var.cosmosdb_account_name
  scope               = "${var.cosmosdb_account_id}/dbs/enterprise_memory/colls/${local.project_id_guid}-system-thread-message-store"
  role_definition_id  = "${var.cosmosdb_account_id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = azapi_resource.foundry_project.output.identity.principalId
}

resource "azurerm_cosmosdb_sql_role_assignment" "cosmosdb_db_sql_role_aifp_entity_store_name" {
  count = var.enable_collection_level_roles ? 1 : 0

  depends_on = [
    azapi_resource.foundry_project_capability_host
  ]
  name                = uuidv5("dns", "${azapi_resource.foundry_project.name}${azapi_resource.foundry_project.output.identity.principalId}entitystore_dbsqlrole")
  resource_group_name = var.resource_group_name
  account_name        = var.cosmosdb_account_name
  scope               = "${var.cosmosdb_account_id}/dbs/enterprise_memory/colls/${local.project_id_guid}-agent-entity-store"
  role_definition_id  = "${var.cosmosdb_account_id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = azapi_resource.foundry_project.output.identity.principalId
}

resource "azurerm_role_assignment" "storage_blob_data_owner_ai_foundry_project" {
  count = var.enable_collection_level_roles ? 1 : 0

  depends_on = [
    azapi_resource.foundry_project_capability_host
  ]
  name                 = uuidv5("dns", "${azapi_resource.foundry_project.name}${azapi_resource.foundry_project.output.identity.principalId}${var.storage_account_name}storageblobdataowner")
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azapi_resource.foundry_project.output.identity.principalId
  condition_version    = "2.0"
  condition            = <<-EOT
  (
    (
      !(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/tags/read'})
      AND !(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/filter/action'})
      AND !(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/tags/write'})
    )
    OR
    (@Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name] StringStartsWithIgnoreCase '${local.project_id_guid}'
    AND @Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name] StringLikeIgnoreCase '*-azureml-agent')
  )
  EOT
}

