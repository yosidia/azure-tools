<#
.SYNOPSIS
  Creates (enables) the project-level capability host that wires a Foundry
  project's Storage, Cosmos DB, and AI Search connections for Standard agent setup.

.DESCRIPTION
  PUTs a project capability host (kind = Agents) mapping:
    storageConnections       -> Azure Storage connection (file/blob storage)
    threadStorageConnections -> Cosmos DB connection (thread/conversation storage)
    vectorStoreConnections   -> AI Search connection (vector store)
  then polls until provisioningState = Succeeded.

  Prerequisites:
    * The 3 connections already exist on the project.
    * The project managed identity already has the required RBAC
      (run Set-FoundryProjectRbac.ps1 first) — otherwise provisioning fails.

  A capability host's connection wiring is immutable: you cannot PUT over an
  existing one with different connection names. Use -RecreateIfExists to delete
  the existing capability host first (e.g. to point it at renamed connections).

.EXAMPLE
  ./Enable-FoundryProjectCapabilityHost.ps1 -SubscriptionId "<your-subscription-id>" -ResourceGroup "<your-resource-group>" `
    -AccountName "<your-foundry-account>" -ProjectName "<your-project>" `
    -StorageConnectionName "<storage-account>-<suffix>" `
    -CosmosConnectionName  "<cosmosdb-account>-<suffix>" `
    -SearchConnectionName  "<search-service>-<suffix>"

.EXAMPLE
  # Re-point an existing capability host at renamed connections
  ./Enable-FoundryProjectCapabilityHost.ps1 -SubscriptionId "<your-subscription-id>" -ResourceGroup "<your-resource-group>" `
    -AccountName "<your-foundry-account>" -ProjectName "<your-project>" `
    -StorageConnectionName "<storage-account>-new" `
    -CosmosConnectionName  "<cosmosdb-account>-new" `
    -SearchConnectionName  "<search-service>-new" `
    -RecreateIfExists
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SubscriptionId,
    [Parameter(Mandatory)][string]$ResourceGroup,
    [Parameter(Mandatory)][string]$AccountName,
    [Parameter(Mandatory)][string]$ProjectName,
    [Parameter(Mandatory)][string]$StorageConnectionName,
    [Parameter(Mandatory)][string]$CosmosConnectionName,
    [Parameter(Mandatory)][string]$SearchConnectionName,
    [string]$CapabilityHostName = "caphostproj",
    [string]$ApiVersion = "2025-06-01",
    # Delete an existing capability host of the same name before the PUT.
    # Required to change connection wiring, since it is otherwise immutable.
    [switch]$RecreateIfExists,
    # Seconds to wait for RBAC propagation before the PUT (set 0 to skip).
    [int]$RbacPropagationDelaySeconds = 60,
    [int]$PollIntervalSeconds = 20,
    [int]$MaxPolls = 18
)

$ErrorActionPreference = "Stop"
function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }

$chUrl = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.CognitiveServices/accounts/$AccountName/projects/$ProjectName/capabilityHosts/$CapabilityHostName`?api-version=$ApiVersion"

# --- Build request body ---
$body = @{
    properties = @{
        capabilityHostKind       = "Agents"
        storageConnections       = @($StorageConnectionName)
        threadStorageConnections = @($CosmosConnectionName)
        vectorStoreConnections   = @($SearchConnectionName)
    }
}
$tmp = New-TemporaryFile
$body | ConvertTo-Json -Depth 8 | Set-Content -Path $tmp -Encoding utf8

try {
    if ($RecreateIfExists) {
        $existing = az rest --method get --url $chUrl -o json 2>$null | ConvertFrom-Json
        if ($existing -and $existing.id) {
            Write-Step "Deleting existing capability host '$CapabilityHostName' (RecreateIfExists)"
            az rest --method delete --url $chUrl -o none
            # Poll until the GET 404s (deletion fully propagated)
            for ($d = 1; $d -le $MaxPolls; $d++) {
                Start-Sleep -Seconds $PollIntervalSeconds
                $still = az rest --method get --url $chUrl -o json 2>$null | ConvertFrom-Json
                if (-not ($still -and $still.id)) {
                    Write-Host "    [$d] deleted"
                    break
                }
                Write-Host "    [$d] $($still.properties.provisioningState)"
            }
        }
        else {
            Write-Host "    no existing capability host to delete"
        }
    }

    if ($RbacPropagationDelaySeconds -gt 0) {
        Write-Step "Waiting $RbacPropagationDelaySeconds s for RBAC propagation"
        Start-Sleep -Seconds $RbacPropagationDelaySeconds
    }

    Write-Step "Creating capability host '$CapabilityHostName' on project '$ProjectName'"
    $resp = az rest --method put --url $chUrl --body "@$tmp" -o json | ConvertFrom-Json
    Write-Host "    submitted; provisioningState=$($resp.properties.provisioningState)"
}
finally {
    Remove-Item $tmp -ErrorAction SilentlyContinue
}

# --- Poll until terminal state ---
Write-Step "Polling for provisioning completion"
$state = ""
for ($i = 1; $i -le $MaxPolls; $i++) {
    Start-Sleep -Seconds $PollIntervalSeconds
    $ch = az rest --method get --url $chUrl -o json 2>$null | ConvertFrom-Json
    $state = $ch.properties.provisioningState
    Write-Host "    [$i] $state"
    if ($state -ne "Creating") { break }
}

if ($state -eq "Succeeded") {
    Write-Step "Capability host '$CapabilityHostName' enabled (Succeeded)."
} else {
    throw "Capability host did not reach 'Succeeded' (last state: $state)."
}
