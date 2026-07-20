# Azure AI Foundry — Private Landing Zone

A private, network-isolated Azure AI Foundry (Azure AI Studio) deployment
pattern: Terraform modules for the infrastructure, plus PowerShell scripts
and KQL queries for the operational tasks that come up once agents are
running in production.

This solution area is organized into three parts:

| Directory | What it is |
|---|---|
| [`terraform/`](terraform/) | Landing-zone Terraform: resource group, private AI Foundry account + project, private AI Search, private Cosmos DB, private Storage, and monitoring — all behind private endpoints, with AAD-only auth and RBAC wired automatically. |
| [`scripts/`](scripts/) | PowerShell operational scripts for tasks Terraform doesn't (and shouldn't) manage: RBAC troubleshooting, capability-host lifecycle, connection wiring, and index cleanup. |
| [`kql/`](kql/) | KQL queries for Azure Monitor / Log Analytics / Application Insights: diagnosing file-search failures and alerting on agent token usage, quality, and failure rate. |

## Why "private"?

The pattern here assumes AI Foundry is deployed with `publicNetworkAccess`
disabled everywhere (Foundry account, AI Search, Cosmos DB, Storage,
Log Analytics/App Insights via a single Azure Monitor Private Link Scope),
data-plane access via managed identity only (no API keys), and agents
running inside a delegated subnet with network injection. This is the
pattern most enterprises need to pass a security review, but it also means
a few things that "just work" in the public/dev-quickstart Foundry setup
need extra plumbing:

- The Foundry project's managed identity needs explicit RBAC on Storage,
  Cosmos DB, and AI Search before its capability host will provision
  (see [`scripts/Set-FoundryProjectRbac.ps1`](scripts/Set-FoundryProjectRbac.ps1)).
- Capability-host connection wiring is immutable once created — re-pointing
  it at renamed connections means delete-then-recreate
  (see [`scripts/Enable-FoundryProjectCapabilityHost.ps1`](scripts/Enable-FoundryProjectCapabilityHost.ps1)).
- Keyless (AAD) connections to a shared/embedding AOAI account aren't always
  exposed cleanly by the portal wizard
  (see [`scripts/Add-KeylessEmbeddingConnection.ps1`](scripts/Add-KeylessEmbeddingConnection.ps1)).
- Diagnosing why file-search is failing usually starts with the AI Search
  index behind it, not the agent itself
  (see [`scripts/Deploy-FoundrySearch-And-Repoint.ps1`](scripts/Deploy-FoundrySearch-And-Repoint.ps1) and
  [`kql/diagnose-filesearch.kql`](kql/diagnose-filesearch.kql)).
- The Basic AI Search SKU caps out at 15 indexes, and file-search vector
  stores each consume one — orphaned indexes from deleted/rebuilt vector
  stores need periodic cleanup
  (see [`scripts/Remove-OrphanedSearchIndexes.ps1`](scripts/Remove-OrphanedSearchIndexes.ps1)).

## Getting started

1. Start with [`terraform/README.md`](terraform/README.md) to stand up the
   landing zone (resource group, Foundry account/project, private AI Search,
   Cosmos DB, Storage, and monitoring).
2. Use [`scripts/README.md`](scripts/README.md) for day-2 operational tasks
   once the infrastructure exists.
3. Use [`kql/README.md`](kql/README.md) to set up alerting and diagnose
   issues in Azure Monitor.
