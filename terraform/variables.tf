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

variable "bypass_ip_ranges" {
  description = "List of IP ranges to whitelist for Databricks access"
  type        = list(string)
  default     = []
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