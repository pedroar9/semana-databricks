provider "databricks" {
  host = "https://adb-4062057039708043.3.azuredatabricks.net/"
  azure_client_id     = var.client_id
  azure_client_secret = var.client_secret
  azure_tenant_id     = var.tenant_id
}
