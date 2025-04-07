output "databricks_workspace_urls" {
  value = {
    for env in local.environments : env => azurerm_databricks_workspace.this[env].workspace_url
  }
  description = "URLs for the Databricks workspaces"
}

output "storage_account_names" {
  value = {
    for env in local.environments : env => azurerm_storage_account.adls[env].name
  }
  description = "Names of the storage accounts"
}

output "service_principal_ids" {
  value = {
    for env in local.environments : env => databricks_service_principal.automation[env].application_id
  }
  description = "Service principal IDs for automation"
}

output "app_insights_instrumentation_key" {
  value = {
    for env in local.environments : env => var.enable_alerts ? azurerm_application_insights.monitoring[env].instrumentation_key : null
  }
  description = "Application Insights instrumentation key for Databricks monitoring"
  sensitive   = true
}
