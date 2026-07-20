# AI Foundry Terraform — Modules

Seven focused child modules used by the root [`../main.tf`](../main.tf).
Each is independently reusable if you only need one piece (e.g. just the
private AI Search module for a non-Foundry project).

| Module | Resources | Notes |
|---|---|---|
| [`foundry/`](foundry/) | `azapi_resource` AI Foundry / AI Services account (`Microsoft.CognitiveServices/accounts`), private endpoint | Uses `azapi` (not `azurerm`) because Foundry's v2 features (project management, agent network injection) are on a preview API surface. Supports both v2 (`foundry_v2 = true`) and a v1 fallback (plain AI Services account). |
| [`foundryProject/`](foundryProject/) | `azapi_resource` project, connections (Storage/Cosmos/AI Search/App Insights), capability host | Creates the default project under a Foundry account and wires its Standard-agent-setup connections + capability host. Connection wiring is immutable after creation — see [`../../scripts/Enable-FoundryProjectCapabilityHost.ps1`](../../scripts/Enable-FoundryProjectCapabilityHost.ps1) for how to re-point it. |
| [`storageaccount/`](storageaccount/) | `azurerm_storage_account`, private endpoints (blob, optional dfs/table) | AAD-only (no shared key), ZRS by default, one private endpoint per enabled sub-resource. |
| [`aisearch/`](aisearch/) | `azurerm_search_service`, private endpoint | SystemAssigned identity, `public_network_access_enabled = false`, configurable SKU (defaults to `basic`; use `standard` if you expect >15 indexes). |
| [`cosmosDB/`](cosmosDB/) | `azurerm_cosmosdb_account`, private endpoint, diagnostic setting | Serverless/session-consistency defaults tuned for agent thread storage; ships diagnostics to the `monitoring` module's Log Analytics workspace. |
| [`monitoring/`](monitoring/) | `azurerm_log_analytics_workspace`, `azurerm_application_insights`, Azure Monitor Private Link Scope (AMPLS) + scoped resources, private endpoint | A single AMPLS fronts both the workspace and App Insights so all telemetry ingestion/query stays private. |
| [`privateEndpoint/`](privateEndpoint/) | `azurerm_private_endpoint`, DNS zone group | Shared helper module — the other modules call this instead of duplicating private-endpoint boilerplate. |

## Design patterns used throughout

- **Private by default** — every module accepts a subnet ID and private DNS
  zone ID(s) and provisions a private endpoint; there is no public-network
  code path left enabled once wired through the root module's
  `terraform.tfvars`.
- **AAD-only data-plane auth** — `disableLocalAuth` / equivalent is set
  wherever the resource type supports it; RBAC role assignments (ARM-level
  and, for Cosmos DB, the data-plane SQL role) grant access instead of keys.
- **`lifecycle { ignore_changes = [tags] }`** on long-lived resources, so an
  external tag-governance policy (e.g. Azure Policy `modify` effect) doesn't
  fight with Terraform on every plan.
- **`azapi_resource` for preview surface** — only used where `azurerm`
  doesn't yet expose the API (Foundry accounts/projects/capability hosts).
  Everything else uses native `azurerm` resources.
