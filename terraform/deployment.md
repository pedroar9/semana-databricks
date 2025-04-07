# Deployment Guide for Databricks Data Intelligence Platform

This guide provides step-by-step instructions for deploying the Databricks Data Intelligence Platform on Microsoft Azure using Terraform. The deployment process has been optimized with a Makefile for efficiency and consistency.

## Prerequisites

### Required Tools

Before proceeding with the deployment, ensure you have installed and configured the following tools:

1. **Terraform** (version 1.2.0 or higher)
   ```
   brew update && brew install terraform
   terraform -v
   ```

2. **Azure CLI**
   ```bash
   brew update && brew install azure-cli
   az --version
   ```

3. **Databricks CLI** (Optional, for post-deployment tasks)
   ```bash
   brew update && brew install databricks
   databricks --version
   ```

### Azure Permissions

The deployment requires an Azure account with permissions to:
- Create resource groups
- Create and manage Azure Databricks workspaces
- Create virtual networks and subnets
- Create storage accounts
- Create key vaults
- Assign RBAC roles

### Azure Login and Service Principal Setup

1. Login to your Azure account:
   ```bash
   az login
   ```

2. Get your subscription ID:
   ```bash
   az account show --query id --output tsv
   ```

3. Create an Azure service principal for Terraform with proper scope:
   ```bash
   az ad sp create-for-rbac --name "Terraform-Databricks" --role Contributor --scopes /subscriptions/YOUR_SUBSCRIPTION_ID
   ```

4. Note the output containing:
   - `appId` (client_id)
   - `password` (client_secret)
   - `tenant` (tenant_id)

5. Configure Azure CLI with the service principal:
   ```bash
   az login --service-principal -u CLIENT_ID -p CLIENT_SECRET --tenant TENANT_ID
   ```

## Deployment Steps

### 1. Clone the Repository

```bash
git clone <repository-url>
cd <repository-directory>
```

### 2. Set up Terraform Cloud (Option A)

1. Create a Terraform Cloud account at [app.terraform.io](https://app.terraform.io) if you don't have one

2. Create an organization or use an existing one

3. Create a new workspace for your Databricks deployment:
   - Workspace Name: `databricks-platform`
   - Workflow Type: Version Control Workflow
   - Connect to your VCS provider and select the repository

4. Configure workspace variables in Terraform Cloud:
   - Navigate to your workspace in Terraform Cloud
   - Go to Variables
   - Add the following variables as sensitive **Terraform variables**:
     - `client_id`: Your Azure service principal client ID
     - `client_secret`: Your Azure service principal client secret
     - `tenant_id`: Your Azure tenant ID
     - `subscription_id`: Your Azure subscription ID
   - Additionally, add these as **Environment variables** for the Azure provider:
     - `ARM_CLIENT_ID`: Same as your client_id
     - `ARM_CLIENT_SECRET`: Same as your client_secret
     - `ARM_TENANT_ID`: Same as your tenant_id
     - `ARM_SUBSCRIPTION_ID`: Same as your subscription_id

5. Update your Terraform configuration in `main.tf` to use Terraform Cloud:

```terraform
terraform {
  cloud {
    organization = "your-organization"
    
    workspaces {
      name = "databricks-platform"
    }
  }
}
```

> **Note:** When using a VCS-connected Terraform Cloud workspace, saved plan files are not allowed. The Makefile has been configured to use direct apply commands instead.

### Azure Storage Backend (Option B)

If you prefer using Azure Storage for state management instead of Terraform Cloud:

```bash
./azure-backend.sh
```

The script will create a resource group, storage account, and container for Terraform state, then output the configuration needed for your backend.

After running the script, update the backend configuration in `main.tf`:

```terraform
terraform {
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "tfstate1234567890"  # Use the name from script output
    container_name       = "tfstate"
    key                  = "databricks.terraform.tfstate"
  }
}
```

### Provider Configuration

Both the Azure and Databricks providers need to be configured properly. When using Terraform Cloud, you should use variables instead of hardcoded credentials:

```terraform
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
  skip_provider_registration = true
  
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
}
terraform init
```

### 2. Deploy Development Environment

```bash
terraform apply -var-file=dev.tfvars
```

### 3. Deploy Production Environment

```bash
terraform apply -var-file=prod.tfvars
```

## Post-Deployment Tasks

### 1. Configure Databricks RBAC

Create groups and assign users to them:
```bash
databricks groups create data-engineers
databricks groups create data-scientists
databricks groups create analysts
```

### 2. Initialize Storage Structure

Create the necessary directories in DBFS and mount points to the ADLS storage:
```bash
databricks fs mkdirs dbfs:/mnt/bronze
databricks fs mkdirs dbfs:/mnt/silver
databricks fs mkdirs dbfs:/mnt/gold
```

### 3. Create Secret Scopes

Set up secret scopes for storing sensitive information:
```bash
databricks secrets create-scope --scope project-secrets --initial-manage-principal users
```

## Security Recommendations

1. **Enable Private Link**: Use private endpoints for enhanced security
   ```bash
   make prod-apply-databricks EXTRA_VARS="-var=enable_private_endpoints=true"
   ```

2. **Restrict IP Access**: Update the `bypass_ip_ranges` variable with your corporate IP ranges

3. **Enable Advanced Threat Protection**: For storage accounts and other sensitive resources

## Troubleshooting

### Common Issues

1. **Network Issues**:
   - Verify subnet delegations for Databricks
   - Check NSG rules for conflicts

2. **Permission Issues**:
   - Ensure service principal has Contributor role
   - For Data Lake Gen2 Filesystem errors, ensure your service principal has the "Storage Blob Data Contributor" role

3. **Authentication Issues**:
   - Ensure service principal credentials are correctly configured
   - When using Terraform Cloud, verify both Terraform variables and Environment variables are set correctly

4. **Terraform Cloud VCS Limitations**:
   - When using VCS-connected workspaces in Terraform Cloud, saved plan files are not allowed

5. **Resource Name Conflicts**:
   - For resources with random suffixes, you may need to import them if changing the naming convention

### Local Deployment Issues

1. **State Lock Errors**:
   ```bash
   terraform force-unlock <LOCK_ID>
   ```

2. **Backend Configuration Conflicts**:
   ```bash
   terraform init -reconfigure
   ```

### Makefile Help

To see all available Makefile targets:

```bash
make help
```

This will show you all available commands for deployment, including:
- `init`: Initialize Terraform
- `dev-deploy`: Deploy development environment
- `prod-deploy`: Deploy production environment
- `local-dev-deploy`: Deploy development environment locally
- `local-prod-deploy`: Deploy production environment locally
- Individual phase targets like `dev-apply-core`, `dev-apply-storage`, etc.

## Support Resources

- [Azure Databricks documentation](https://learn.microsoft.com/en-us/azure/databricks/)
- [Terraform Azure Provider documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Terraform Databricks Provider documentation](https://registry.terraform.io/providers/databricks/databricks/latest/docs)
