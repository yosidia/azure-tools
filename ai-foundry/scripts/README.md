# AI Foundry — Operational Scripts

PowerShell scripts for day-2 operational tasks on a private Azure AI Foundry
deployment: things Terraform doesn't (and shouldn't) manage because they're
one-off actions, troubleshooting steps, or lifecycle operations on existing
resources.

All scripts use `az rest` / Azure CLI under an already-authenticated session
(`az login`) and Entra ID (AAD) auth throughout — no API keys. All parameters
are mandatory with no hardcoded defaults; run each with `-?` or read the
comment-based help (`Get-Help ./Script.ps1 -Full`) for full parameter docs.

| Script | Purpose |
|---|---|
| [`Set-FoundryProjectRbac.ps1`](Set-FoundryProjectRbac.ps1) | Grants a Foundry project's managed identity the ARM roles (Storage, Cosmos DB, AI Search) plus the Cosmos DB data-plane role it needs before its capability host can provision. Idempotent. |
| [`Enable-FoundryProjectCapabilityHost.ps1`](Enable-FoundryProjectCapabilityHost.ps1) | Creates (or, with `-RecreateIfExists`, re-creates) the project capability host that wires Storage/Cosmos DB/AI Search connections for Standard agent setup, and polls until provisioning succeeds. |
| [`Add-KeylessEmbeddingConnection.ps1`](Add-KeylessEmbeddingConnection.ps1) | Adds an AAD (keyless) Azure OpenAI connection to every project in a Foundry account, so the file-search vectorizer uses token auth instead of failing against an account with `disableLocalAuth = true`. |
| [`Deploy-FoundrySearch-And-Repoint.ps1`](Deploy-FoundrySearch-And-Repoint.ps1) | Deploys a new private, Standard-SKU AI Search service (to escape a Basic-tier 15-index quota wall), wires RBAC, and re-points every project's capability host at it. |
| [`Remove-OrphanedSearchIndexes.ps1`](Remove-OrphanedSearchIndexes.ps1) | Lists AI Search indexes with document/storage/vector size, and optionally deletes empty or named indexes to free up quota. Defaults to list-only; deletion requires an explicit switch and confirmation. |

## Typical flow

For a new project on an existing private Foundry account:

```powershell
./Set-FoundryProjectRbac.ps1 -SubscriptionId ... -ResourceGroup ... -AccountName ... -ProjectName ... `
    -StorageAccountName ... -CosmosAccountName ... -SearchServiceName ...

./Enable-FoundryProjectCapabilityHost.ps1 -SubscriptionId ... -ResourceGroup ... -AccountName ... -ProjectName ... `
    -StorageConnectionName ... -CosmosConnectionName ... -SearchConnectionName ...
```

When file-search stops working or hits quota, start with
[`../kql/diagnose-filesearch.kql`](../kql/diagnose-filesearch.kql), then use
`Remove-OrphanedSearchIndexes.ps1` to clear space or
`Deploy-FoundrySearch-And-Repoint.ps1` to move to a bigger SKU.

## Requirements

- Azure CLI (`az`), logged in (`az login`) with rights to manage the target
  resources (Cognitive Services accounts/projects, Storage, Cosmos DB,
  AI Search, role assignments).
- PowerShell 7+.
- Run from a host that can reach the private endpoints if the resources have
  `publicNetworkAccess` disabled (a VNet-joined VM/jumpbox, or via Bastion) —
  `az rest` calls against management.azure.com work from anywhere, but the
  AI Search data-plane calls in `Remove-OrphanedSearchIndexes.ps1` need
  network line-of-sight to the private endpoint.
