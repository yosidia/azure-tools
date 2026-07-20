<#
.SYNOPSIS
  Lists (and optionally deletes) Azure AI Search indexes on a private search
  service to free up the index-count quota used by Foundry file-search vector
  stores.

.DESCRIPTION
  The Foundry "file search" tool creates one Azure AI Search index per vector
  store. On the Basic SKU the hard cap is 15 indexes, so repeatedly creating /
  rebuilding vector stores across multiple projects eventually returns:

      429 Too Many Requests
      "The quota has exceeded for the search resource."

  This script authenticates to the search data plane with your Entra (AAD)
  token, lists every index with its document count + storage + vector size so
  you can spot orphaned/empty indexes, and can delete the ones you choose.

  NETWORK: if the search service is private (publicNetworkAccess = Disabled),
  run this from a host that can resolve/reach the private endpoint (a jumpbox /
  VM on the same VNet, or via Bastion). Running from outside the VNet returns 403.

  SAFETY: defaults to LIST-ONLY. Deletion requires an explicit switch and prompts
  for confirmation. Deleting an index that still backs an active vector store will
  break that agent's file search until it is rebuilt — only remove indexes you
  know are orphaned (e.g. 0 documents, or belonging to deleted/test agents).

.EXAMPLE
  # List all indexes with sizes (no changes)
  ./Remove-OrphanedSearchIndexes.ps1 -SearchServiceName <your-search-service>

.EXAMPLE
  # Delete only empty (0-document) indexes, with confirmation
  ./Remove-OrphanedSearchIndexes.ps1 -SearchServiceName <your-search-service> -RemoveEmpty

.EXAMPLE
  # Delete specific indexes by name
  ./Remove-OrphanedSearchIndexes.ps1 -SearchServiceName <your-search-service> -IndexNames index_old_abc123, index_test_def456
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][string]$SearchServiceName,
    [string]$ApiVersion = "2024-07-01",
    # Delete every index that currently has 0 documents.
    [switch]$RemoveEmpty,
    # Delete these specific indexes by name.
    [string[]]$IndexNames
)

$ErrorActionPreference = "Stop"
$endpoint = "https://$SearchServiceName.search.windows.net"

function Get-SearchToken {
    az account get-access-token --resource "https://search.azure.com" --query accessToken -o tsv
}

$token   = Get-SearchToken
$headers = @{ Authorization = "Bearer $token" }

# --- List indexes ---
try {
    $list = Invoke-RestMethod -Uri "$endpoint/indexes?api-version=$ApiVersion&`$select=name" -Headers $headers -TimeoutSec 30
}
catch {
    throw "Could not reach the search data plane ($endpoint). If this is 403/timeout, run from inside the VNet (private endpoint). Underlying error: $($_.Exception.Message)"
}

$names = @($list.value.name)
Write-Host "Found $($names.Count) index(es) on '$SearchServiceName' (Basic cap = 15):" -ForegroundColor Cyan

$rows = foreach ($n in $names) {
    $s = $null
    try { $s = Invoke-RestMethod -Uri "$endpoint/indexes/$n/stats?api-version=$ApiVersion" -Headers $headers -TimeoutSec 30 } catch {}
    [pscustomobject]@{
        Name            = $n
        Documents       = if ($s) { $s.documentCount } else { "?" }
        StorageMB       = if ($s) { [math]::Round($s.storageSize / 1MB, 2) } else { "?" }
        VectorMB        = if ($s -and $s.PSObject.Properties.Name -contains 'vectorIndexSize') { [math]::Round($s.vectorIndexSize / 1MB, 2) } else { "?" }
    }
}
$rows | Sort-Object Documents | Format-Table -AutoSize

# --- Decide what to delete ---
$targets = @()
if ($IndexNames) { $targets += $IndexNames }
if ($RemoveEmpty) { $targets += ($rows | Where-Object { $_.Documents -eq 0 }).Name }
$targets = $targets | Sort-Object -Unique | Where-Object { $_ }

if (-not $targets) {
    Write-Host "`nList-only mode. Re-run with -RemoveEmpty and/or -IndexNames <names> to delete." -ForegroundColor Yellow
    return
}

Write-Host "`nThe following $($targets.Count) index(es) will be DELETED:" -ForegroundColor Yellow
$targets | ForEach-Object { Write-Host "  - $_" }

foreach ($t in $targets) {
    if ($PSCmdlet.ShouldProcess($t, "Delete AI Search index")) {
        Invoke-RestMethod -Method Delete -Uri "$endpoint/indexes/$t`?api-version=$ApiVersion" -Headers $headers -TimeoutSec 30
        Write-Host "  deleted: $t" -ForegroundColor Green
    }
}
Write-Host "Done. Indexes freed; retry the file-search upload." -ForegroundColor Cyan
