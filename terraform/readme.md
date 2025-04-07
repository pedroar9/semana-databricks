# Databricks Data Intelligence Platform for UberEats

This repository contains Terraform code for deploying a comprehensive Databricks Data Intelligence Platform on Microsoft Azure. The infrastructure is designed to support the UberEats use case, implementing a modern data architecture with Medallion (Bronze, Silver, Gold) layers, real-time data processing, machine learning, and generative AI capabilities.

## Architecture Overview

The platform includes:

- **Databricks Workspaces** for dev and prod environments
- **Data Lakehouse** with Delta Lake storage
- **Unity Catalog** for centralized governance
- **Machine Learning** infrastructure for model training and deployment
- **MLOps** infrastructure for model management
- **Security** configurations with RBAC and network isolation
- **Monitoring** infrastructure for operational visibility

## Prerequisites

Before deploying this infrastructure, ensure you have:

1. **Azure Subscription** with sufficient permissions to create resources
2. **Terraform** (version 1.2.0 or higher) installed
3. **Azure CLI** installed and configured
4. **Databricks CLI** installed (optional, for post-deployment tasks)
5. **Required Azure Resource Providers registered** in your subscription:
   - Microsoft.Databricks
   - Microsoft.Storage
   - Microsoft.KeyVault
   - Microsoft.Network
   - Microsoft.Insights
   - Microsoft.OperationalInsights
   - Microsoft.Compute
   - Microsoft.Authorization

## Repository Structure

```
.
├── locals.tf               # Environment configurations and shared variables
├── infrastructure.tf       # Core Azure resources (resource groups, VNets, storage)
├── databricks.tf           # Databricks workspaces, clusters, and SQL warehouses
├── unity_catalog.tf        # Unity Catalog resources (metastore, catalogs, schemas)
├── security.tf             # User groups, permissions, and network security
├── variables.tf            # Input variable definitions in organized sections
├── outputs.tf              # Consolidated outputs from all resources
├── providers.tf            # Provider configurations
├── terraform.tfvars        # Default variable values
├── dev.tfvars              # Development environment variables
├── prod.tfvars             # Production environment variables
├── deployment.md           # Detailed deployment guide
└── README.md               # Documentation
```

This simplified structure makes the Terraform configuration more maintainable with logical separation of concerns, easier to navigate with related resources grouped together, and more consistent in style and approach.

## Deployment Instructions

### 1. Set Up Terraform Cloud or Azure Backend

You have two options for managing Terraform state:

#### Option A: Terraform Cloud (Recommended)

1. Create a Terraform Cloud account and workspace
2. Configure workspace variables for your Azure service principal credentials:
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
3. Initialize Terraform with cloud configuration:

```bash
terraform login
terraform init
```

> **Note:** When using a VCS-connected Terraform Cloud workspace, saved plan files are not allowed. The Makefile has been configured to use direct apply commands instead.

#### Option B: Azure Storage Backend

```bash
./azure-backend.sh
terraform init
```

#### Option C: Local Deployment

For testing or when Terraform Cloud is not available, you can deploy locally:

1. Create a `credentials.auto.tfvars` file with your Azure credentials:
```
client_id       = "your-client-id"
client_secret   = "your-client-secret"
tenant_id       = "your-tenant-id"
subscription_id = "your-subscription-id"
```

2. Use the local deployment targets in the Makefile:
```bash
make local-dev-deploy
make local-prod-deploy
```

### 2. Deployment Options

#### Option A: Using the Makefile (Recommended)

The simplest way to deploy is using the provided Makefile:

```bash
make init

make dev-deploy

make prod-deploy
```

#### Option B: Local Deployment

For local deployment without Terraform Cloud:

```bash
make local-dev-deploy

make local-prod-deploy
```

#### Option C: Phased Deployment Approach

To avoid circular dependencies and permission issues, deploy resources in phases:

##### Phase 1: Deploy Core Azure Resources

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

### 3. Create a Production Environment

Follow the same approach for production after testing the development environment:

```bash
make prod-deploy
```

### 4. Destroy Resources (if needed)

```bash
make dev-destroy

make prod-destroy
```

## Key Features

### Separate Dev/Prod Environments

The infrastructure is designed with separate environments for development and production, each with:

- Isolated VNets and subnets
- Environment-specific security settings
- Appropriate cluster sizing and configurations
- Distinct storage containers

### Medallion Architecture

The Data Lakehouse is organized following the Medallion Architecture pattern:

- **Bronze Layer**: Raw data ingestion (landing zone)
- **Silver Layer**: Validated and transformed data
- **Gold Layer**: Business-level aggregates and features

### Security Best Practices

- RBAC with least privilege access
- Network isolation with private endpoints (optional)
- Secrets management with Azure Key Vault
- IP allowlisting for workspace access

### Monitoring and Alerting

- Azure Monitor integration
- Custom alert rules for cluster failures
- Storage utilization monitoring
- Diagnostic settings for operational visibility

## Customization

### Resource Sizing

Adjust the node types and cluster sizes in `main.tf` under the `env_config` local variable:

```terraform
env_config = {
  dev = {
    # ...
    node_type     = "Standard_DS3_v2"
    min_workers   = 2
    max_workers   = 8
    # ...
  }
}
```

### Enabling/Disabling Features

Control which features are enabled using the variable files:

```terraform
enable_ml_integration = true 
enable_alerts = true         
enable_private_endpoints = false
enable_customer_managed_keys = false
```

These feature flags correspond to the variables defined in `optional_vars.tf` and allow you to selectively enable or disable components of the infrastructure.

## Post-Deployment Steps

After deploying the infrastructure:

1. **Configure RBAC**: Add users to the appropriate groups in Databricks
2. **Initialize Unity Catalog**: Complete the setup of schemas and tables
3. **Deploy Initial Notebooks**: Create the folder structure for your data pipelines
4. **Set Up CI/CD**: Implement CI/CD pipelines for code deployment

## Best Practices

- **State Management**: Use Terraform Cloud or Azure Storage for remote state management
- **Secret Management**: Store sensitive credentials in Terraform Cloud variables or Azure Key Vault
- **Secret Rotation**: Implement regular rotation of access keys and credentials
- **Network Security**: Limit access to Databricks workspaces through private endpoints
- **Cost Management**: Use cluster policies and autotermination to control costs
- **Tagging**: Maintain consistent tagging for resources to track costs and ownership
- **Phased Deployment**: Follow the phased deployment approach to avoid circular dependencies

## Troubleshooting

### Common Issues

1. **Deployment Failures**: Check Azure activity logs and Terraform output
2. **Network Connectivity**: Verify NSG rules and subnet delegations
3. **Permission Issues**: Ensure the Azure service principal has sufficient permissions
4. **Authentication Issues**: Ensure service principal credentials are correctly configured in both providers
5. **Circular Dependencies**: Use the phased deployment approach to avoid provider configuration issues
6. **Storage Access**: For Data Lake Gen2 Filesystem errors, ensure your service principal has the "Storage Blob Data Contributor" role
7. **Terraform Cloud VCS Limitations**: When using VCS-connected workspaces in Terraform Cloud, saved plan files are not allowed

### Local Deployment Issues

1. **State Lock Errors**: If you encounter state lock errors, you may need to force-unlock the state:
   ```bash
   terraform force-unlock <LOCK_ID>
   ```

2. **Backend Configuration Conflicts**: When switching between Terraform Cloud and local backends, you may need to reconfigure:
   ```bash
   terraform init -reconfigure
   ```

### Debugging Tips

- Enable Terraform logging: `export TF_LOG=DEBUG`
- Check Azure Resource Manager error messages
- Verify Azure subscription quotas
- For authentication issues, verify your credentials in `credentials.auto.tfvars` or environment variables

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
