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

output "metastore_id" {
  value       = local.unity_catalog_enabled ? local.metastore_id : "Unity Catalog not enabled"
  description = "ID of the Unity Catalog metastore (if enabled)"
}

output "catalog_names" {
  value = {
    for key, catalog in databricks_catalog.domains : key => catalog.name
  }
  description = "Names of the Unity Catalog catalogs"
}
