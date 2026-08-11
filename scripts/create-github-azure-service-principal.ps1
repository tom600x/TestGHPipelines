param(
    [string]$SubscriptionId = "c73e01ad-eb1a-4584-addc-a98fa1388c9a",
    [string]$ResourceGroup = "GitHub-Test-RG-CUS",
    [string]$Location = "centralus",
    [string]$ServicePrincipalName = "gh-actions-github-test-rg-cus"
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI is not installed or not available in PATH."
}

Write-Host "Checking Azure CLI login..."
az account show --output none | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Run 'az login' before executing this script."
}

az account set --subscription $SubscriptionId | Out-Null

$rgExists = az group exists --name $ResourceGroup
if ($rgExists -eq "false") {
    Write-Host "Creating resource group $ResourceGroup in $Location..."
    az group create --name $ResourceGroup --location $Location | Out-Null
}

Write-Host "Creating service principal '$ServicePrincipalName'..."
$sp = az ad sp create-for-rbac `
    --name $ServicePrincipalName `
    --role Contributor `
    --scopes "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup" `
    --sdk-auth | ConvertFrom-Json

Write-Host ""
Write-Host "GitHub repository secrets:"
Write-Host "AZURE_CLIENT_ID=$($sp.clientId)"
Write-Host "AZURE_CLIENT_SECRET=$($sp.clientSecret)"
Write-Host "AZURE_TENANT_ID=$($sp.tenantId)"
Write-Host "AZURE_SUBSCRIPTION_ID=$SubscriptionId"
