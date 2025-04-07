variable "environment" {
  description = "Target environment to deploy (dev or prod). Leave empty to use deploy_all_environments variable."
  type        = string
  default     = "dev"
  validation {
    condition     = var.environment == "" || contains(["dev", "prod"], var.environment)
    error_message = "Environment must be either dev or prod."
  }
}

variable "deploy_all_environments" {
  description = "Whether to deploy all environments (dev and prod) or just the one specified in the environment variable"
  type        = bool
  default     = false
}

variable "prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "ubereats"

  validation {
    condition     = length(var.prefix) <= 10
    error_message = "Prefix must be 10 characters or less to avoid storage account name length issues."
  }
}

variable "location" {
  description = "Azure region to deploy resources"
  type        = string
  default     = "eastus2"
}

variable "resource_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "enable_unity_catalog" {
  description = "Enable Unity Catalog for the workspace"
  type        = bool
  default     = true
}

variable "enable_ml_integration" {
  description = "Whether to enable Machine Learning integration"
  type        = bool
  default     = true
}

variable "enable_alerts" {
  description = "Whether to enable monitoring alerts"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Whether to enable monitoring for Databricks resources"
  type        = bool
  default     = true
}

variable "enable_private_endpoints" {
  description = "Whether to enable private endpoints for Databricks"
  type        = bool
  default     = false
}

variable "enable_customer_managed_keys" {
  description = "Whether to enable customer-managed keys for encryption"
  type        = bool
  default     = false
}

variable "bypass_ip_ranges" {
  description = "IP ranges to bypass network restrictions"
  type        = list(string)
  default     = []
}

variable "no_public_ip" {
  description = "Whether to disable public IP for Databricks workspaces"
  type        = bool
  default     = true
}

variable "client_id" {
  description = "Azure service principal client ID"
  type        = string
  sensitive   = true
}

variable "client_secret" {
  description = "Azure service principal client secret"
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "Azure tenant ID"
  type        = string
}

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "spark_version" {
  description = "Spark version for Databricks clusters"
  type        = string
  default     = "11.3.x-scala2.12"
}

variable "node_type_id" {
  description = "Node type for Databricks clusters"
  type        = string
  default     = "Standard_DS3_v2"
}

variable "ops_email" {
  description = "Email address for operations team"
  type        = string
  default     = "ops@example.com"
}

variable "enable_streaming" {
  description = "Whether to enable streaming features"
  type        = bool
  default     = false
}

variable "databricks_sku" {
  description = "The SKU of the Databricks workspace (standard, premium, or trial)"
  type        = string
  default     = "premium"
  validation {
    condition     = contains(["standard", "premium", "trial"], var.databricks_sku)
    error_message = "The databricks_sku must be one of: standard, premium, or trial."
  }
}
