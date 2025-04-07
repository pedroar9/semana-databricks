resource "azurerm_storage_account" "metastore" {
  name                     = "${replace(var.prefix, "-", "")}ucmetastore"
  resource_group_name      = azurerm_resource_group.this[local.environments[0]].name
  location                 = azurerm_resource_group.this[local.environments[0]].location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true
  tags                     = local.env_config[local.environments[0]].tags
}

resource "azurerm_storage_data_lake_gen2_filesystem" "unity_catalog" {
  name               = "unity-catalog"
  storage_account_id = azurerm_storage_account.metastore.id
}

resource "databricks_metastore" "this" {
  provider = databricks.account
  name = "ubereats-unity-catalog"
  storage_root = "abfss://unity-catalog@${azurerm_storage_account.metastore.name}.dfs.core.windows.net/"
  owner = "admins"
  region = "eastus2"
  force_destroy = false
}

resource "databricks_metastore_assignment" "this" {
  provider = databricks.account
  for_each = toset(local.environments)
  
  metastore_id = databricks_metastore.this.id
  workspace_id = azurerm_databricks_workspace.this[each.key].workspace_id
  default_catalog_name = "ubereats_delivery_services"
}

resource "databricks_catalog" "domains" {
  for_each = {
    for pair in setproduct(local.environments, ["ubereats_delivery_services"]) : "${pair[0]}-${pair[1]}" => {
      env    = pair[0]
      domain = pair[1]
      config = local.env_config[pair[0]]
    }
  }

  metastore_id = databricks_metastore.this.id
  name         = "${each.value.env}_${each.value.domain}"
  comment      = "Catalog for ${each.value.domain} domain in ${each.value.env} environment"
}
resource "databricks_schema" "medallion" {
  for_each = {
    for entry in setproduct(
      local.environments,
      ["ubereats_delivery_services"],
      ["bronze", "silver", "gold"]
    ) : "${entry[0]}-${entry[1]}-${entry[2]}" => {
      env     = entry[0]
      domain  = entry[1]
      zone    = entry[2]
    }
  }

  catalog_name = databricks_catalog.domains["${each.value.env}-${each.value.domain}"].name
  name         = each.value.zone
  comment      = "${each.value.zone} layer for ${each.value.domain} in ${each.value.env} environment"
}
resource "databricks_grants" "catalog_usage" {
  for_each = {
    for pair in setproduct(local.environments, ["ubereats_delivery_services"], ["data_engineers", "data_scientists", "data_analysts"]) : "${pair[0]}-${pair[1]}-${pair[2]}" => {
      env     = pair[0]
      catalog = pair[1]
      group   = pair[2]
    }
  }

  catalog = databricks_catalog.domains["${each.value.env}-${each.value.catalog}"].name

  grant {
    principal  = lookup({
      "data_engineers" = databricks_group.data_engineers.display_name,
      "data_scientists" = databricks_group.data_scientists.display_name,
      "data_analysts" = databricks_group.data_analysts.display_name
    }, each.value.group)
    privileges = each.value.group == "data_engineers" ? ["USE_CATALOG", "CREATE", "MODIFY"] : ["USE_CATALOG", "SELECT"]
  }
}
resource "databricks_metastore_data_access" "unity_catalog_access" {
  provider = databricks.account
  metastore_id = databricks_metastore.this.id
  name         = "storage-credential"
  azure_service_principal {
    directory_id   = var.tenant_id
    application_id = var.client_id
    client_secret  = var.client_secret
  }
  comment = "Metastore credential for dedicated Unity Catalog storage account"
  is_default = true
}
