# Deployment Guide for Databricks Data Intelligence Platform

This guide provides step-by-step instructions for deploying the Databricks Data Intelligence Platform on Microsoft Azure using Terraform. The deployment process has been optimized with a Makefile for efficiency and consistency, supporting both local deployments and Terraform Cloud integration.

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
cd <repository-directory>/terraform
```

### Architecture Overview

This deployment creates a Databricks Data Intelligence Platform with the following key components:

- **Single Domain Architecture**: The platform is designed around a single business domain (`ubereats_delivery_services`) for simplified management
- **Medallion Architecture**: Implements bronze, silver, and gold data layers for each domain
- **Dual Environment**: Separate development and production environments with appropriate sizing
- **Standardized Naming**: All resources use consistent, predictable naming patterns without random suffixes

### 2. Set up Credentials

Create a credentials file for your Azure service principal:

```bash
cp credentials.auto.tfvars.template credentials.auto.tfvars
```

Edit `credentials.auto.tfvars` with your Azure service principal credentials:

```hcl
client_id       = "your-client-id"
client_secret   = "your-client-secret"
tenant_id       = "your-tenant-id"
subscription_id = "your-subscription-id"
```

> **Important:** The `credentials.auto.tfvars` file is excluded from Git via `.gitignore` to prevent accidentally committing sensitive information.

### 3. Choose Deployment Method

You have three deployment options:

#### Option A: Local Deployment

This option uses your local machine to execute Terraform commands with a local state file.

1. First, ensure your credentials are set up correctly in `credentials.auto.tfvars`

2. Initialize Terraform in local mode:
   ```bash
   make local-mode
   make local-init
   ```

3. For development environment deployment:
   ```bash
   # For a complete deployment in one step
   make local-dev-deploy
   
   # OR for phased deployment
   make dev-plan-core
   make dev-apply-core
   make dev-plan-storage
   make dev-apply-storage
   make dev-plan-databricks
   make dev-apply-databricks
   ```

4. For production environment deployment:
   ```bash
   # For a complete deployment in one step
   make local-prod-deploy
   ```

5. After deployment, verify the outputs:
   ```bash
   terraform output
   ```

#### Option B: Terraform Cloud Deployment

1. Create a Terraform Cloud account at [app.terraform.io](https://app.terraform.io) if you don't have one

2. Create an organization or use an existing one (default: `engenharia-academy`)

3. Create a new workspace for your Databricks deployment (default: `databricks-platform`):
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

5. Use the Makefile targets for Terraform Cloud deployment:

```bash
make cloud-init

make cloud-dev-deploy

make cloud-prod-deploy
```

> **Note:** When using a VCS-connected Terraform Cloud workspace, saved plan files are not allowed. The Makefile has been configured to use direct apply commands instead.

#### Option C: Azure Storage Backend

If you prefer using Azure Storage for state management:

```bash
./azure-backend.sh
```

The script will create a resource group, storage account, and container for Terraform state, then output the configuration needed for your backend.

### 4. Phased Deployment Approach

The Makefile supports a phased deployment approach to avoid provider configuration issues:

#### Phase 1: Deploy Core Azure Resources

```bash
make dev-apply-core
```

Or manually:
```bash
terraform plan -var-file=dev.tfvars -target=azurerm_resource_group.this -target=azurerm_virtual_network.this -target=azurerm_subnet.public -target=azurerm_subnet.private -target=azurerm_databricks_workspace.this
terraform apply -var-file=dev.tfvars -target=azurerm_resource_group.this -target=azurerm_virtual_network.this -target=azurerm_subnet.public -target=azurerm_subnet.private -target=azurerm_databricks_workspace.this
```

##### Phase 2: Deploy Storage Resources

```bash
make dev-apply-storage
```

Or manually:
```bash
terraform plan -var-file=dev.tfvars -target=azurerm_storage_account.adls -target=azurerm_storage_data_lake_gen2_filesystem.this
terraform apply -var-file=dev.tfvars -target=azurerm_storage_account.adls -target=azurerm_storage_data_lake_gen2_filesystem.this
```

##### Phase 3: Deploy Databricks Resources

```bash
make dev-apply-databricks
```

Or manually:
```bash
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

### 5. Complete Deployment

To deploy the entire environment in one step:

```bash
make dev-deploy

make prod-deploy
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

5. **Standardized Resource Naming**:
   - This deployment uses standardized resource names without random suffixes for better maintainability
   - Resource naming follows predictable patterns (e.g., `ubereats-dev-workspace`, `ubereats-dev-rg`, `adlsubereatsdev`)
   - If you're migrating from a previous deployment with random suffixes, you may need to import existing resources

6. **GitHub Push Protection**:
   - Ensure sensitive files like `credentials.auto.tfvars` and `set-env.sh` are in `.gitignore`
   - Use template files (e.g., `credentials.auto.tfvars.template`) for sharing credential structures without actual secrets

### Local Deployment Issues

1. **State Lock Errors**:
   ```bash
   terraform force-unlock <LOCK_ID>
   ```

2. **Backend Configuration Conflicts**:
   ```bash
   terraform init -reconfigure
   ```

3. **Switching Between Local and Cloud Backends**:
   ```bash
   # Switch to local backend
   make local-mode
   
   # Switch to Terraform Cloud backend
   make cloud-mode
   ```

### Makefile Help

To see all available Makefile targets:

```bash
make help
```

This will show you all available commands for deployment, including:

#### Local Deployment Commands
- `local-init`: Initialize Terraform locally
- `local-dev-deploy`: Deploy development environment locally
- `local-prod-deploy`: Deploy production environment locally

#### Terraform Cloud Commands
- `cloud-init`: Initialize Terraform with Terraform Cloud backend
- `cloud-dev-deploy`: Deploy development environment using Terraform Cloud
- `cloud-prod-deploy`: Deploy production environment using Terraform Cloud

#### Standard Deployment Commands
- `dev-deploy`: Deploy complete development environment
- `prod-deploy`: Deploy complete production environment
- `dev-destroy`: Destroy development environment
- `prod-destroy`: Destroy production environment

#### Phased Deployment Commands
- `dev-apply-core`: Deploy core Azure resources for development
- `dev-apply-storage`: Deploy storage resources for development
- `dev-apply-databricks`: Deploy Databricks resources for development
- Similar commands exist for production with `prod-` prefix

## Support Resources

- [Azure Databricks documentation](https://learn.microsoft.com/en-us/azure/databricks/)
- [Terraform Azure Provider documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Terraform Databricks Provider documentation](https://registry.terraform.io/providers/databricks/databricks/latest/docs)