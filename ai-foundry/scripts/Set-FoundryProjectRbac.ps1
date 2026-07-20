<#
.SYNOPSIS
  Assigns the ARM RBAC roles + Cosmos DB data-plane role required by a Foundry
  project's managed identity to use its Storage, Cosmos DB, and AI Search
  connections (Standard agent setup).

.DESCRIPTION
  Resolves the project's SystemAssigned managed identity principalId, then grants
  the same role set the default Foundry project uses:
    Storage : Storage Blob Data Contributor, Storage Blob Data Owner
    Cosmos  : Cosmos DB Operator, DocumentDB Account Contributor,
              Cosmos DB Account Reader Role, + Cosmos built-in Data Contributor (data-plane)
    Search  : Search Index Data Contributor, Search Service Contributor

  Idempotent: re-running skips assignments that already exist.

.EXAMPLE
  ./Set-FoundryProjectRbac.ps1 -SubscriptionId "<your-subscription-id>" -ResourceGroup "<your-resource-group>" `
    -AccountName "<your-foundry-account>" -ProjectName "<your-project>" `
    -StorageAccountName "<storage-account>" -CosmosAccountName "<cosmosdb-account>" `
    -SearchServiceName "<search-service>"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SubscriptionId,
    [Parameter(Mandatory)][string]$ResourceGroup,
    [Parameter(Mandatory)][string]$AccountName,
    [Parameter(Mandatory)][string]$ProjectName,
    [Parameter(Mandatory)][string]$StorageAccountName,
    [Parameter(Mandatory)][string]$CosmosAccountName,
    [Parameter(Mandatory)][string]$SearchServiceName,
    [string]$ApiVersion = "2025-06-01",
    # Cosmos built-in "Cosmos DB Built-in Data Contributor" data-plane role definition id
    [string]$CosmosDataRoleDefinitionId = "00000000-0000-0000-0000-000000000002"
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }

# --- Resolve the project managed identity principalId ---
Write-Step "Resolving managed identity for project '$ProjectName'"
$projUrl = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.CognitiveServices/accounts/$AccountName/projects/$ProjectName`?api-version=$ApiVersion"
$proj = az rest --method get --url $projUrl -o json | ConvertFrom-Json
$principalId = $proj.identity.principalId
if (-not $principalId) { throw "Project '$ProjectName' has no SystemAssigned identity principalId." }
Write-Host "    principalId = $principalId"

# --- Build scopes ---
$storageScope = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Storage/storageAccounts/$StorageAccountName"
$cosmosScope  = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.DocumentDB/databaseAccounts/$CosmosAccountName"
$searchScope  = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Search/searchServices/$SearchServiceName"

# --- ARM role assignments ---
$assignments = @(
    @{ Role = "Search Index Data Contributor"; Scope = $searchScope }
    @{ Role = "Search Service Contributor";    Scope = $searchScope }
    @{ Role = "Cosmos DB Operator";            Scope = $cosmosScope }
    @{ Role = "DocumentDB Account Contributor"; Scope = $cosmosScope }
    @{ Role = "Cosmos DB Account Reader Role"; Scope = $cosmosScope }
    @{ Role = "Storage Blob Data Contributor"; Scope = $storageScope }
    @{ Role = "Storage Blob Data Owner";       Scope = $storageScope }
)

Write-Step "Assigning ARM roles"
foreach ($a in $assignments) {
    az role assignment create `
        --assignee-object-id $principalId `
        --assignee-principal-type ServicePrincipal `
        --role $a.Role `
        --scope $a.Scope `
        -o none 2>$null
    if ($LASTEXITCODE -eq 0) { Write-Host "    OK   : $($a.Role)" -ForegroundColor Green }
    else { Write-Host "    SKIP/FAIL : $($a.Role) (may already exist)" -ForegroundColor Yellow }
}

# --- Cosmos DB data-plane role assignment ---
Write-Step "Assigning Cosmos DB built-in Data Contributor (data-plane)"
$existing = az cosmosdb sql role assignment list --account-name $CosmosAccountName -g $ResourceGroup -o json |
    ConvertFrom-Json |
    Where-Object { $_.principalId -eq $principalId -and ($_.roleDefinitionId -split '/')[-1] -eq $CosmosDataRoleDefinitionId }

if ($existing) {
    Write-Host "    OK   : Cosmos data-plane role already assigned" -ForegroundColor Green
} else {
    az cosmosdb sql role assignment create `
        --account-name $CosmosAccountName -g $ResourceGroup `
        --scope $cosmosScope `
        --principal-id $principalId `
        --role-definition-id $CosmosDataRoleDefinitionId `
        -o none
    if ($LASTEXITCODE -eq 0) { Write-Host "    OK   : Cosmos data-plane role assigned" -ForegroundColor Green }
    else { throw "Failed to assign Cosmos data-plane role." }
}

Write-Step "Done. RBAC for project '$ProjectName' (principalId $principalId) is in place."
