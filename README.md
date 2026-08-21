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

---

## Multi-Environment CI/CD Workflows

This repository contains three workflows that together implement a build-once, promote-through-environments pipeline:

| Workflow file | Purpose |
|---|---|
| `build-and-deploy-dev.yml` | Builds the app, stores the artifact, and deploys to Development on every push to `main` |
| `deploy.yml` | Reusable deployment workflow called by the other two; not triggered directly |
| `promote.yml` | Manually promotes a previously built artifact to UAT or Production after an approval gate |

### Workflow overview

```
push to main
     │
     ▼
build-and-deploy-dev.yml
  ├── build job  →  uploads artifact "webapp" (kept 30 days)
  └── deploy-dev job  →  calls deploy.yml (environment: Development)

manual trigger (promote.yml)
  ├── approval job  →  waits for required reviewer(s) to approve
  └── deploy job    →  calls deploy.yml (environment: UAT or Production)
                       using the artifact from a chosen prior build run
```

---

### GitHub Environments — required setup

All Azure credentials and app settings are stored **per GitHub Environment**, which means Development, UAT, and Production can each point at completely different Azure service connections (different subscriptions, tenants, or app registrations).

Go to **Settings → Environments** and create the following environments:

| Environment name | Used by |
|---|---|
| `Development` | `build-and-deploy-dev.yml` on every push to `main` |
| `UAT` | `promote.yml` when target is UAT |
| `Production` | `promote.yml` when target is Production |
| *(value of `APPROVERS_ENV`)* | `promote.yml` approval gate (see below) |

For each of the three deployment environments (`Development`, `UAT`, `Production`) configure:

#### Secrets (Settings → Environments → \<name\> → Environment secrets)

| Secret name | Description |
|---|---|
| `AZURE_CLIENT_ID` | Client ID of the Azure App Registration / managed identity for this environment |
| `AZURE_TENANT_ID` | Azure AD tenant ID for this environment |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID for this environment |

> **Different service connections per environment:** Because these secrets are set independently on each environment, Development and UAT can share the same App Registration values while Production uses an entirely different one — no workflow changes are required.

#### Variables (Settings → Environments → \<name\> → Environment variables)

| Variable name | Description |
|---|---|
| `APP_NAME` | Name of the Azure Web App to deploy to in this environment |

#### Azure OIDC federated credential

Each App Registration used above must have a federated identity credential added so GitHub Actions can authenticate without a client secret:

- **Issuer:** `https://token.actions.githubusercontent.com`
- **Subject:** `repo:<org>/<repo>:environment:<EnvironmentName>`  
  e.g. `repo:tom600x/TestGHPipelines:environment:Production`
- **Audience:** `api://AzureADTokenExchange`

---

### Approval gate setup

Before a promotion to UAT or Production is allowed to proceed, the `promote.yml` workflow pauses at an **approval job**. The GitHub Environment that enforces the approval is named by the repository variable `APPROVERS_ENV`.

#### Step 1 — Create the approval environment

Go to **Settings → Environments → New environment** and create an environment named `approval-gate` (or any name you prefer).

Under **Environment protection rules**, enable **Required reviewers** and add the GitHub users or teams who are permitted to approve deployments.

#### Step 2 — Set the repository variable

Go to **Settings → Secrets and variables → Actions → Variables → Repository variables** and add:

| Variable name | Value | Description |
|---|---|---|
| `APPROVERS_ENV` | `approval-gate` | Name of the GitHub Environment used as the approval gate. Change this value at any time to switch to a different environment (and therefore a different set of reviewers) without editing any workflow files. |

> **Tip:** If `APPROVERS_ENV` is not set the workflow defaults to an environment named `approval-gate`.

#### How the approval flow works

1. A developer runs **Actions → Promote to UAT or Production**, enters the run ID of the build they want to promote, and selects the target environment.
2. The `approval` job starts and immediately pauses, waiting for a required reviewer to approve.
3. GitHub sends a notification to every reviewer configured on the `APPROVERS_ENV` environment.
4. Once a reviewer approves, the `deploy` job runs and the artifact is deployed to the chosen environment using that environment's Azure service connection.

---

### Promoting a build — step by step

1. Find the **run ID** of the `Build and Deploy Dev` workflow run whose artifact you want to promote.  
   The run ID is the number in the URL:  
   `https://github.com/<org>/<repo>/actions/runs/<RUN_ID>`

2. Go to **Actions → Promote to UAT or Production → Run workflow**.

3. Fill in the inputs:

   | Input | Description |
   |---|---|
   | `artifact_run_id` | The run ID from step 1 |
   | `target_environment` | `UAT` or `Production` |

4. The workflow pauses at the approval gate. The configured reviewer(s) will receive a notification and can approve or reject at  
   **Actions → Promote to UAT or Production → \<run\> → Review deployments**.

5. After approval the artifact is downloaded from the selected run and deployed to the chosen environment.
