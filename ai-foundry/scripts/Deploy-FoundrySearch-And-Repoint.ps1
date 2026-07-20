<#
.SYNOPSIS
  Deploy a best-practice (Standard SKU, private, AAD-only) Azure AI Search
  service and re-point every project in a Foundry account to use it.

.DESCRIPTION
  Workaround for hitting the per-tier index quota on an existing Basic search
  service (Basic caps at 15 indexes, and Foundry's file-search tool creates one
  index per vector store). This script:
    1. Creates a new Standard search service (private endpoint, SystemAssigned
       identity, disableLocalAuth = true, public access disabled).
    2. Creates its private endpoint + DNS zone group (privatelink.search.windows.net).
    3. RBAC:
         - new search MI  -> "Cognitive Services OpenAI User" on the embedding
           accounts (so the integrated vectorizer can call them over AAD).
         - each project MI -> "Search Index Data Contributor" +
           "Search Service Contributor" on the new search.
    4. For every project under the account: creates a new CognitiveSearch
       connection (with ResourceId metadata) pointing at the new service and
       recreates the project capability host (vectorStore -> new search), keeping
       the existing storage + thread (cosmos) connections.

  NOTE: existing file-search vector stores live in the OLD service and are not
  migrated; re-upload documents to rebuild them on the new service.

.NOTES
  Idempotent-ish: re-running reuses the same search service if -SearchName is
  passed, recreates connections (PUT) and recreates capability hosts.

.EXAMPLE
  ./Deploy-FoundrySearch-And-Repoint.ps1 `
    -SubscriptionId "<your-subscription-id>" `
    -ResourceGroup  "<your-resource-group>" `
    -Location       "eastus2" `
    -AccountName    "<your-foundry-account>" `
    -PeSubnetId      "/subscriptions/<sub-id>/resourceGroups/<network-rg>/providers/Microsoft.Network/virtualNetworks/<vnet>/subnets/<pe-subnet>" `
    -SearchDnsZoneId "/subscriptions/<sub-id>/resourceGroups/<network-rg>/providers/Microsoft.Network/privateDnsZones/privatelink.search.windows.net" `
    -EmbeddingAccountNames @("<your-foundry-account>", "<your-aoai-account>")
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SubscriptionId,
    [Parameter(Mandatory)][string]$ResourceGroup,
    [Parameter(Mandatory)][string]$Location,
    [Parameter(Mandatory)][string]$AccountName,
    [string]$SearchName       = "",   # blank => generate a unique name
    [string]$Sku              = "standard",
    [int]$ReplicaCount        = 1,
    [int]$PartitionCount      = 1,
    [Parameter(Mandatory)][string]$PeSubnetId,
    [Parameter(Mandatory)][string]$SearchDnsZoneId,
    # Cognitive/embedding accounts the search vectorizer must reach via AAD.
    [Parameter(Mandatory)][string[]]$EmbeddingAccountNames,
    [string]$SearchMgmtApi    = "2025-05-01",
    [string]$FoundryApi       = "2025-06-01",
    [int]$RbacPropagationDelaySeconds = 180
)
$ErrorActionPreference = "Stop"
function Step($m){ Write-Host "==> $m" -ForegroundColor Cyan }
function Sub($m){ Write-Host "    $m" }

if (-not $SearchName) { $SearchName = "ais-fdy-" + ([guid]::NewGuid().ToString('N').Substring(0,6)) }
$searchId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Search/searchServices/$SearchName"
$searchMgmtUrl = "https://management.azure.com$searchId`?api-version=$SearchMgmtApi"
$acctBase = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.CognitiveServices/accounts/$AccountName"

function Put-Json($url, $obj) {
    $tmp = New-TemporaryFile
    $obj | ConvertTo-Json -Depth 12 | Set-Content -Path $tmp -Encoding utf8
    try { az rest --method put --url $url --body "@$tmp" -o json } finally { Remove-Item $tmp -ErrorAction SilentlyContinue }
}
function Ensure-Role($principalId, $role, $scope) {
    az role assignment create --assignee-object-id $principalId --assignee-principal-type ServicePrincipal --role $role --scope $scope -o none 2>$null
    if ($LASTEXITCODE -eq 0) { Sub "OK   : $role" } else { Sub "exists/skip: $role" }
}

#############################################
# 1) Create the search service
#############################################
Step "Creating search service '$SearchName' ($Sku, private, AAD-only)"
$existing = az rest --method get --url $searchMgmtUrl -o json 2>$null | ConvertFrom-Json
if ($existing -and $existing.id) {
    Sub "already exists (provisioningState=$($existing.properties.provisioningState))"
} else {
    Put-Json $searchMgmtUrl @{
        location = $Location
        sku      = @{ name = $Sku }
        identity = @{ type = "SystemAssigned" }
        properties = @{
            replicaCount        = $ReplicaCount
            partitionCount      = $PartitionCount
            publicNetworkAccess = "disabled"
            disableLocalAuth    = $true
            networkRuleSet      = @{ bypass = "AzureServices" }
        }
    } | Out-Null
}
Step "Waiting for search provisioning"
for ($i = 1; $i -le 30; $i++) {
    Start-Sleep -Seconds 20
    $svc = az rest --method get --url $searchMgmtUrl -o json 2>$null | ConvertFrom-Json
    $ps = $svc.properties.provisioningState; $st = $svc.properties.status
    Sub "[$i] provisioningState=$ps status=$st"
    if ($ps -eq "succeeded" -and $st -in @("running","provisioning")) { break }
    if ($ps -eq "failed") { throw "Search provisioning failed." }
}
$searchMi = $svc.identity.principalId
Sub "search MI principalId = $searchMi"

#############################################
# 2) Private endpoint + DNS zone group
#############################################
Step "Creating private endpoint for '$SearchName'"
$peName = "$SearchName-pe-01"
$peExists = az network private-endpoint show -n $peName -g $ResourceGroup -o json 2>$null
if (-not $peExists) {
    az network private-endpoint create -n $peName -g $ResourceGroup -l $Location `
        --subnet $PeSubnetId `
        --private-connection-resource-id $searchId `
        --group-id searchService `
        --connection-name "$peName" -o none
    Sub "private endpoint created"
    az network private-endpoint dns-zone-group create `
        --endpoint-name $peName -g $ResourceGroup -n default `
        --zone-name search --private-dns-zone $SearchDnsZoneId -o none
    Sub "DNS zone group created"
} else { Sub "private endpoint already exists" }

#############################################
# 3) RBAC - search MI -> OpenAI (vectorizer)
#############################################
Step "Granting search MI access to embedding accounts (AAD vectorizer)"
foreach ($acct in $EmbeddingAccountNames) {
    $scope = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.CognitiveServices/accounts/$acct"
    Ensure-Role $searchMi "Cognitive Services OpenAI User" $scope
}

#############################################
# 4) Per-project: roles + new connection
#############################################
Step "Discovering projects under '$AccountName'"
$projects = (az rest --method get --url "$acctBase/projects?api-version=$FoundryApi" -o json | ConvertFrom-Json).value
Sub ("projects: " + (($projects | ForEach-Object { $_.name.Split('/')[-1] }) -join ', '))

$projInfo = @()
foreach ($p in $projects) {
    $pName = $p.name.Split('/')[-1]
    $pPrincipal = $p.identity.principalId
    Step "Project '$pName' : grant search roles + create new search connection"
    Ensure-Role $pPrincipal "Search Index Data Contributor" $searchId
    Ensure-Role $pPrincipal "Search Service Contributor"    $searchId

    # existing storage + cosmos connection names (keep them)
    $conns = (az rest --method get --url "$acctBase/projects/$pName/connections?api-version=$FoundryApi" -o json | ConvertFrom-Json).value
    $storageConn = ($conns | Where-Object { $_.properties.category -eq "AzureStorageAccount" } | Select-Object -First 1).name
    $cosmosConn  = ($conns | Where-Object { $_.properties.category -eq "CosmosDb" } | Select-Object -First 1).name
    if (-not $storageConn -or -not $cosmosConn) { Sub "WARN: missing storage/cosmos connection on $pName - skipping caphost"; continue }

    $suffix = ([System.BitConverter]::ToString((New-Object System.Security.Cryptography.MD5CryptoServiceProvider).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($pName.ToLower()))).Replace("-","").ToLower()).Substring(0,8)
    $newSearchConn = "$SearchName-$suffix".ToLower()
    Put-Json "$acctBase/projects/$pName/connections/$newSearchConn`?api-version=$FoundryApi" @{
        properties = @{ category="CognitiveSearch"; target="https://$SearchName.search.windows.net"; authType="AAD";
            metadata=@{ ApiType="Azure"; ApiVersion="2025-05-01-preview"; ResourceId=$searchId; location=$Location } }
    } | Out-Null
    Sub "new search connection: $newSearchConn (storage=$storageConn, cosmos=$cosmosConn)"
    $projInfo += [pscustomobject]@{ Project=$pName; Storage=$storageConn; Cosmos=$cosmosConn; Search=$newSearchConn }
}

#############################################
# 5) RBAC propagation, then recreate caphosts
#############################################
Step "Waiting $RbacPropagationDelaySeconds s for RBAC propagation"
Start-Sleep -Seconds $RbacPropagationDelaySeconds

foreach ($pi in $projInfo) {
    $pName = $pi.Project
    $chUrl = "$acctBase/projects/$pName/capabilityHosts/caphostproj?api-version=$FoundryApi"
    Step "Recreating capability host on '$pName' -> $($pi.Search)"
    $cur = az rest --method get --url $chUrl -o json 2>$null | ConvertFrom-Json
    if ($cur -and $cur.id) {
        az rest --method delete --url $chUrl -o none
        for ($d=1; $d -le 18; $d++) { Start-Sleep -Seconds 20; $s = az rest --method get --url $chUrl -o json 2>$null | ConvertFrom-Json; if (-not ($s -and $s.id)) { Sub "[$d] deleted"; break } else { Sub "[$d] $($s.properties.provisioningState)" } }
    }
    Put-Json $chUrl @{
        properties = @{
            capabilityHostKind       = "Agents"
            storageConnections       = @($pi.Storage)
            threadStorageConnections = @($pi.Cosmos)
            vectorStoreConnections   = @($pi.Search)
        }
    } | Out-Null
    for ($i=1; $i -le 18; $i++) { Start-Sleep -Seconds 20; $ch = az rest --method get --url $chUrl -o json 2>$null | ConvertFrom-Json; $st = $ch.properties.provisioningState; Sub "[$i] $st"; if ($st -ne "Creating") { break } }
}

Step "DONE. New search '$SearchName' serving all projects."
Write-Host "RESULT searchName=$SearchName" -ForegroundColor Green
Write-Host "RESULT searchId=$searchId" -ForegroundColor Green
$projInfo | Format-Table -AutoSize
