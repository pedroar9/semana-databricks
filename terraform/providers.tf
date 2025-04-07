provider "databricks" {
  host                        = azurerm_databricks_workspace.this["dev"].workspace_url
  azure_client_id             = var.client_id
  azure_client_secret         = var.client_secret
  azure_tenant_id             = var.tenant_id
  azure_workspace_resource_id = azurerm_databricks_workspace.this["dev"].id
}
