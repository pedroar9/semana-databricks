provider "databricks" {
  host                        = data.azurerm_databricks_workspace.existing["dev"].workspace_url
  azure_client_id             = var.client_id
  azure_client_secret         = var.client_secret
  azure_tenant_id             = var.tenant_id
  azure_workspace_resource_id = data.azurerm_databricks_workspace.existing["dev"].id
}
