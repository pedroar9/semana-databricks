# Consolidated outputs file

# Workspace outputs
output "databricks_workspace_urls" {
  value = {
    for env in local.environments : env => azurerm_databricks_workspace.this[env].workspace_url
  }
  description = "URLs for the Databricks workspaces"
}

# Storage outputs
output "storage_account_names" {
  value = {
    for env in local.environments : env => azurerm_storage_account.adls[env].name
  }
  description = "Names of the storage accounts"
}

# Service principal outputs
output "service_principal_ids" {
  value = {
    for env in local.environments : env => databricks_service_principal.automation[env].application_id
  }
  description = "Service principal IDs for automation"
}

# Application Insights outputs
output "app_insights_instrumentation_key" {
  value = {
    for env in local.environments : env => var.enable_alerts ? azurerm_application_insights.monitoring[env].instrumentation_key : null
  }
  description = "Application Insights instrumentation key for Databricks monitoring"
  sensitive   = true
}

# Unity Catalog outputs
output "metastore_id" {
  value       = databricks_metastore.this.id
  description = "ID of the Unity Catalog metastore"
}

output "catalog_names" {
  value = {
    for key, catalog in databricks_catalog.domains : key => catalog.name
  }
  description = "Names of the Unity Catalog catalogs"
}
