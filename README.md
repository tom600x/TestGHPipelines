# Azure GitHub Actions Service Principal Setup

This repository includes a PowerShell script to create an Azure service principal for GitHub Actions and grant it Contributor access to the resource group `GitHub-Test-RG-CUS` in subscription `c73e01ad-eb1a-4584-addc-a98fa1388c9a`.

## Prerequisites

- Azure CLI installed and logged in
- Permission to create app registrations and role assignments in the target subscription

## Run the script

From the repository root:

```powershell
pwsh -File .\scripts\create-github-azure-service-principal.ps1
```

## Manual Azure CLI Commands

```bash
az login
az account set --subscription c73e01ad-eb1a-4584-addc-a98fa1388c9a
az group create --name GitHub-Test-RG-CUS --location centralus
az ad sp create-for-rbac \
  --name gh-actions-github-test-rg-cus \
  --role Contributor \
  --scopes /subscriptions/c73e01ad-eb1a-4584-addc-a98fa1388c9a/resourceGroups/GitHub-Test-RG-CUS \
  --sdk-auth
```

## GitHub Secrets to add

Add these values to your GitHub repository secrets:

- `AZURE_CLIENT_ID`
- `AZURE_CLIENT_SECRET`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
