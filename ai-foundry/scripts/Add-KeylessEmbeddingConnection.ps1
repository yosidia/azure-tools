<#
  Option A (keyless): add an Entra-ID (AAD) Azure OpenAI embedding connection to
  every project in the Foundry account, pointing at a key-auth-independent AOAI
  resource, so the file-search vectorizer uses the MODERN token path (no listKeys)
  instead of the legacy key-fetch that fails when disableLocalAuth=true.

.EXAMPLE
  ./Add-KeylessEmbeddingConnection.ps1 `
    -SubscriptionId "<your-subscription-id>" `
    -ResourceGroup  "<your-resource-group>" `
    -AccountName    "<your-foundry-account>" `
    -AoaiName       "<your-aoai-account>" `
    -AoaiEndpoint   "https://<your-aoai-account>.openai.azure.com/" `
    -Location       "eastus2"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SubscriptionId,
    [Parameter(Mandatory)][string]$ResourceGroup,
    [Parameter(Mandatory)][string]$AccountName,
    [Parameter(Mandatory)][string]$AoaiName,
    [Parameter(Mandatory)][string]$AoaiEndpoint,
    [string]$Location    = "eastus2",
    [string]$FoundryApi  = "2025-06-01"
)
$ErrorActionPreference = "Stop"
function Step($m){ Write-Host "==> $m" -ForegroundColor Cyan }
function Sub($m){ Write-Host "    $m" }

$acctBase = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.CognitiveServices/accounts/$AccountName"
$aoaiId   = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.CognitiveServices/accounts/$AoaiName"

function Set-JsonResource($url, $obj) {
    $tmp = New-TemporaryFile
    $obj | ConvertTo-Json -Depth 10 | Set-Content -Path $tmp -Encoding utf8
    try { az rest --method put --url $url --body "@$tmp" -o json } finally { Remove-Item $tmp -ErrorAction SilentlyContinue }
}

$projects = (az rest --method get --url "$acctBase/projects?api-version=$FoundryApi" -o json | ConvertFrom-Json).value
foreach ($p in $projects) {
    $pName = $p.name.Split('/')[-1]
    $pPrincipal = $p.identity.principalId
    Step "Project '$pName'"

    # 1) keyless data-plane access to the AOAI embedding resource
    az role assignment create --assignee-object-id $pPrincipal --assignee-principal-type ServicePrincipal `
        --role "Cognitive Services OpenAI User" --scope $aoaiId -o none 2>$null
    if ($LASTEXITCODE -eq 0) { Sub "OK   : Cognitive Services OpenAI User on $AoaiName" } else { Sub "exists/skip: OpenAI User" }

    # 2) AAD Azure OpenAI connection
    $suffix = ([System.BitConverter]::ToString((New-Object System.Security.Cryptography.MD5CryptoServiceProvider).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($pName.ToLower()))).Replace("-","").ToLower()).Substring(0,8)
    $connName = "$AoaiName-$suffix".ToLower()
    Set-JsonResource "$acctBase/projects/$pName/connections/$connName`?api-version=$FoundryApi" @{
        properties = @{
            category = "AzureOpenAI"
            target   = $AoaiEndpoint
            authType = "AAD"
            metadata = @{ ApiType = "Azure"; ResourceId = $aoaiId; location = $Location }
        }
    } | Out-Null
    Sub "connection created: $connName -> $AoaiEndpoint (AAD)"
}
Step "DONE. Keyless AOAI embedding connections added to all projects."
