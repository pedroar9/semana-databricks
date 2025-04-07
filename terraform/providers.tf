terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = ">= 1.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0.0"
    }
  }
  required_version = ">= 1.2.0"
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  skip_provider_registration = true
  client_id                 = var.client_id
  client_secret             = var.client_secret
  tenant_id                 = var.tenant_id
  subscription_id           = var.subscription_id
}

provider "databricks" {
  alias                  = "account"
  host                   = "https://accounts.azuredatabricks.net"
  azure_client_id        = var.client_id
  azure_client_secret    = var.client_secret
  azure_tenant_id        = var.tenant_id
  auth_type              = "azure-cli"
}

provider "databricks" {
  host = var.databricks_host
  azure_client_id     = var.client_id
  azure_client_secret = var.client_secret
  azure_tenant_id     = var.tenant_id
  auth_type           = "azure-cli"
}
