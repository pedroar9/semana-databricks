variable "enable_ml_integration" {
  description = "Enable Azure ML workspace integration"
  type        = bool
  default     = false
}

variable "enable_private_endpoints" {
  description = "Enable private endpoints for enhanced security"
  type        = bool
  default     = false
}

variable "enable_alerts" {
  description = "Enable monitoring alerts"
  type        = bool
  default     = false
}

variable "enable_streaming" {
  description = "Enable streaming capabilities"
  type        = bool
  default     = false
}

variable "enable_customer_managed_keys" {
  description = "Enable customer-managed keys for DBFS encryption"
  type        = bool
  default     = false
}

variable "databricks_sku" {
  description = "SKU for Databricks workspace (standard, premium, or trial)"
  type        = string
  default     = "premium"

  validation {
    condition     = contains(["standard", "premium", "trial"], var.databricks_sku)
    error_message = "Databricks SKU must be 'standard', 'premium', or 'trial'."
  }
}
