# Databricks Data Intelligence Platform

## Overview

This repository contains the infrastructure as code (IaC) for deploying a complete Databricks Data Intelligence Platform on Microsoft Azure. The platform is designed to support data engineering, analytics, and machine learning workloads in a secure and scalable environment.

## Architecture

The platform follows a modern data architecture with the following components:

- **Azure Databricks Workspace**: Premium tier workspace with VNet injection for enhanced security
- **Data Lake Storage**: Azure Data Lake Storage Gen2 with bronze, silver, and gold zones
- **Unity Catalog**: Centralized governance for data assets (optional)
- **Compute Resources**: Auto-scaling job clusters and SQL warehouses
- **Security**: Key Vault integration, secret scopes, and RBAC

## Features

- **Multi-Environment Support**: Separate development and production environments
- **Medallion Architecture**: Structured data layers (bronze, silver, gold)
- **Infrastructure as Code**: Complete Terraform configuration
- **CI/CD Ready**: Supports both local deployment and Terraform Cloud workflows
- **Standardized Naming**: Consistent resource naming without random suffixes

## Getting Started

### Prerequisites

- Terraform (v1.2.0+)
- Azure CLI
- Azure Subscription with Contributor access
- Service Principal with appropriate permissions

### Quick Start

1. Clone this repository
2. Navigate to the terraform directory
3. Configure your Azure credentials
4. Run the deployment using the provided Makefile

```bash
# Set up credentials
cp terraform/credentials.auto.tfvars.template terraform/credentials.auto.tfvars
# Edit the file with your service principal details

# Deploy development environment
cd terraform
make local-dev-deploy
```

For detailed deployment instructions, see the [Deployment Guide](terraform/deployment.md).

## Project Structure

```
├── terraform/             # Terraform configuration files
│   ├── infrastructure.tf  # Core Azure resources
│   ├── databricks.tf      # Databricks workspace and resources
│   ├── unity_catalog.tf   # Unity Catalog configuration
│   ├── security.tf        # Security groups and permissions
│   ├── Makefile           # Deployment automation
│   └── deployment.md      # Detailed deployment guide
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
