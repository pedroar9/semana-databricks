# Storage account for Unity Catalog metastore
resource "azurerm_storage_account" "metastore" {
  name                     = "${replace(var.prefix, "-", "")}ucmetastore"
  resource_group_name      = azurerm_resource_group.this[local.environments[0]].name
  location                 = azurerm_resource_group.this[local.environments[0]].location
  account_tier             = "Standard"
  account_replication_type = "GRS"  # Changed to GRS for better redundancy
  account_kind             = "StorageV2"
  is_hns_enabled           = true  # Hierarchical namespace required for ADLS Gen2
  min_tls_version          = "TLS1_2"
  tags                     = merge(local.env_config[local.environments[0]].tags, {
    Purpose = "Unity Catalog Metastore"
  })
}

# Container for Unity Catalog data
resource "azurerm_storage_data_lake_gen2_filesystem" "unity_catalog" {
  name               = "unity-catalog"
  storage_account_id = azurerm_storage_account.metastore.id
  
  # Add default ACLs for the service principal
  ace {
    type = "user"
    id = var.client_id
    permissions = "rwx"
  }
}

# Unity Catalog metastore
resource "databricks_metastore" "this" {
  provider = databricks.account
  name = "ubereats-unity-catalog"
  storage_root = "abfss://unity-catalog@${azurerm_storage_account.metastore.name}.dfs.core.windows.net/"
  owner = "admins"
  region = azurerm_resource_group.this[local.environments[0]].location
  force_destroy = false
  delta_sharing_scope = "INTERNAL"  # Restrict delta sharing to internal only
  delta_sharing_recipient_token_lifetime_in_seconds = 259200  # 3 days
}

# Storage credential for the metastore
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
  read_only = false
}

# Assign metastore to workspaces
resource "databricks_metastore_assignment" "this" {
  provider = databricks.account
  for_each = toset(local.environments)
  
  metastore_id = databricks_metastore.this.id
  workspace_id = azurerm_databricks_workspace.this[each.key].workspace_id
  default_catalog_name = "${each.key}_ubereats_delivery_services"  # Environment-specific default catalog
}

# Create catalogs for each domain and environment
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
  properties = {
    purpose = "${each.value.domain} data"
    environment = each.value.env
    domain = each.value.domain
    owner = "data_platform_team"
  }
}

# Create schemas for medallion architecture (bronze, silver, gold)
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
  properties = {
    layer = each.value.zone
    retention_period = each.value.zone == "bronze" ? "90 days" : (each.value.zone == "silver" ? "180 days" : "365 days")
    quality_level = each.value.zone == "bronze" ? "raw" : (each.value.zone == "silver" ? "validated" : "curated")
    purpose = each.value.zone == "bronze" ? "Data ingestion" : (each.value.zone == "silver" ? "Data transformation" : "Business consumption")
  }
}

# Grant permissions on catalogs to different user groups
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
    privileges = each.value.group == "data_engineers" ? ["USE_CATALOG", "CREATE", "MODIFY", "CREATE_SCHEMA", "CREATE_TABLE", "CREATE_VIEW", "CREATE_FUNCTION"] : (
        each.value.group == "data_scientists" ? ["USE_CATALOG", "SELECT", "EXECUTE", "CREATE_VIEW", "CREATE_FUNCTION"] : ["USE_CATALOG", "SELECT", "EXECUTE"]
      )
  }
}

# Grant schema-level permissions
resource "databricks_grants" "schema_usage" {
  for_each = {
    for entry in setproduct(
      local.environments,
      ["ubereats_delivery_services"],
      ["bronze", "silver", "gold"],
      ["data_engineers", "data_scientists", "data_analysts"]
    ) : "${entry[0]}-${entry[1]}-${entry[2]}-${entry[3]}" => {
      env     = entry[0]
      domain  = entry[1]
      zone    = entry[2]
      group   = entry[3]
    }
  }

  catalog = databricks_catalog.domains["${each.value.env}-${each.value.domain}"].name
  schema = databricks_schema.medallion["${each.value.env}-${each.value.domain}-${each.value.zone}"].name

  grant {
    principal  = lookup({
      "data_engineers" = databricks_group.data_engineers.display_name,
      "data_scientists" = databricks_group.data_scientists.display_name,
      "data_analysts" = databricks_group.data_analysts.display_name
    }, each.value.group)
    privileges = each.value.group == "data_engineers" ? ["USE_SCHEMA", "CREATE", "MODIFY", "SELECT", "CREATE_TABLE", "CREATE_VIEW", "CREATE_FUNCTION"] : (
        each.value.group == "data_scientists" ? (
          each.value.zone == "bronze" ? ["USE_SCHEMA", "SELECT"] : ["USE_SCHEMA", "SELECT", "CREATE_VIEW", "CREATE_FUNCTION"]
        ) : ["USE_SCHEMA", "SELECT"]
      )
  }
}

# Create external location for data lake integration
resource "databricks_external_location" "data_lake" {
  for_each = toset(local.environments)
  
  name = "${each.key}_data_lake"
  url  = "abfss://data@${azurerm_storage_account.adls[each.key].name}.dfs.core.windows.net/"
  credential_name = databricks_metastore_data_access.unity_catalog_access.name
  comment = "External location for ${each.key} data lake storage"
  
  depends_on = [databricks_metastore_assignment.this]
}

# Grant permissions on external location
resource "databricks_grants" "external_location" {
  for_each = toset(local.environments)
  
  external_location = databricks_external_location.data_lake[each.key].name
  
  grant {
    principal  = databricks_group.data_engineers.display_name
    privileges = ["CREATE_EXTERNAL_TABLE", "READ_FILES", "WRITE_FILES"]
  }
}
