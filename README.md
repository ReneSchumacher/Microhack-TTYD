# Problem Statement

You want to build up an own TTYD microhack environment. Build 'Talk to your data' environment with azd.

Source https://aka.ms/ttyd

# Solution

If you are a coach. This azd repo is deploying the entire microhack experience. Define some basic variables and spin it up.

# Architecture

- The Entra tenant where you as a user is logged in is the Fabric tenant
- Test users and a group are beeing created in this tenant
- The Azure Subscription must assossiated to this tenant
- All resources are placed into a single resource group
- Access from SSMS to the Managed instance is public.
- Access from Fabric is private goes over a gateway

# Software Requirements (tested with):

- Windows OS
- Terraform > 1.14.3
- Azure Developer CLI 1.25.5
- SQLServer Powershell Module > 22.4.5.1
- Powershell 7.6.2
- AZ cli (SQL module) >2.85.0

# MCAPS Tenant restrictions

- VNET subnet going to private every night.
- Storage account -> blocks SAS key usage every night! -> public network access disabled!
  MI changes to entra id login only

  I'm working on a solution.

# Required permissions

- AZD Deployment user needs Global Admin, Fabric Admin and Subscription Owner Role
- Resource provider for Fabric and PowerPlatform has to be registered on the subscription

# Instructions

Follow these steps in order to deploy the environment.

### 0. Fulfill the requirements

Make sure you meet everything listed under [Software Requirements](#software-requirements-tested-with) and [Requirements of permissions](#requirements-of-permissions) before you start.

### 1. Clone this repository

```powershell
git clone <repository-url>
cd Microhack-TTYD
```

### 2. Authenticate

Sign in to both the Azure Developer CLI and the Azure CLI against the Fabric tenant.

```powershell
azd auth login --tenant-id "<YOUR TENANT: xyz.onmicrosoft.com>"
az login --tenant <YOUR TENANT: xyz.onmicrosoft.com>
```

### 3. Create and select an azd environment

1. Replace `<YOURPREFIX>` with your own environment name.
2. Replace Subscription ID
3. Replace ADMIN_LOGIN
4. Replace OBJECT_ID
5. Replace Password
6. DATABSE_COUNT is the number of peritcipants
7. Replace Tenant_Domain

```powershell
azd env new <YOURPREFIX>
azd env select <YOURPREFIX>
```

### 4. Configure the environment variables

Adjust the values to match your subscription, tenant, and admin identities.

```powershell
azd env set APP_SERVICE_PLAN_SKU=B1
azd env set AZURE_APP_SERVICE_WEB_APP_NAME=app-sqlhack-hack1
azd env set AZURE_LOCATION=swedencentral
azd env set AZURE_SUBSCRIPTION_ID=a1e862d1-ec96-44d1-a069-563ac034ffad
azd env set SQL_ADMIN_LOGIN=sqlmiadmin
azd env set SQL_MI_ENTRA_ADMIN_LOGIN=admin@MngEnvMCAP538867.onmicrosoft.com
azd env set SQL_MI_ENTRA_ADMIN_OBJECT_ID=ff2a66c2-5b54-41a9-9ec3-12f9f1c9553e
azd env set SQL_PASSWORD="Password123!"
azd env set TAILSPIN_TOYS_USER_DATABASE_COUNT=2
azd env set TENANT_DOMAIN=MngEnvMCAP538867.onmicrosoft.com
```

### 5. Deploy

```powershell
azd up
```

# What azd is doing

The Azure Developer CLI (`azd`) is an open-source command-line tool that streamlines provisioning and deploying applications to Azure. It ties together your infrastructure-as-code (here, Terraform), application source, and environment configuration into a single, repeatable workflow, so a full environment can be stood up with one `azd up`. It also runs lifecycle hooks at defined stages, which this project uses to validate prerequisites and load data automatically.

### Preprovision

1. Checks if user has needed permissions
2. Check if subscrption has right resource provider registered (Fabric, PowerPlatform)

Important: The WAM (Windows Web Access Manager) is popping up in the background sometimes.

### Infra Deployment

1. Deploys Infra via Terraform
2. Deploys App into webshop

### Postprovision

1. Loads data to the databases

# Cleanup

1. Run Destroy-Environment.ps1

# Disclaimer

This repository is provided "as is", without warranty of any kind, express or implied. I do not guarantee that it is fit for any particular purpose, and I accept no liability for any damage, data loss, or costs arising from its use. It is released under the [MIT License](https://opensource.org/licenses/MIT). Use this repository at your own risk.
