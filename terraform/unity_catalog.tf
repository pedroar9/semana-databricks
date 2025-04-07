resource "databricks_catalog" "domains" {
  for_each = local.unity_catalog_enabled ? {
    for pair in setproduct(local.environments, ["ubereats_delivery_services"]) : "${pair[0]}-${pair[1]}" => {
      env    = pair[0]
      domain = pair[1]
      config = local.env_config[pair[0]]
    }
  } : {}

  name         = "${each.value.env}_${each.value.domain}"
  comment      = "Catalog for ${each.value.domain} domain in ${each.value.env} environment"
  properties = {
    purpose = "${each.value.domain} data"
    environment = each.value.env
    domain = each.value.domain
    owner = "data_platform_team"
  }
}
resource "databricks_schema" "medallion" {
  for_each = local.unity_catalog_enabled ? {
    for entry in setproduct(
      local.environments,
      ["ubereats_delivery_services"],
      ["bronze", "silver", "gold"]
    ) : "${entry[0]}-${entry[1]}-${entry[2]}" => {
      env     = entry[0]
      domain  = entry[1]
      zone    = entry[2]
    }
  } : {}

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
resource "databricks_grants" "catalog_usage" {
  for_each = local.unity_catalog_enabled ? {
    for pair in setproduct(local.environments, ["ubereats_delivery_services"], ["data_engineers", "data_scientists", "data_analysts"]) : "${pair[0]}-${pair[1]}-${pair[2]}" => {
      env     = pair[0]
      catalog = pair[1]
      group   = pair[2]
    }
  } : {}

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

resource "databricks_grants" "schema_usage" {
  for_each = local.unity_catalog_enabled ? {
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
  } : {}

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

resource "databricks_storage_credential" "external" {
  for_each = local.unity_catalog_enabled ? toset(local.environments) : []
  
  name = "${each.key}_storage_credential"
  
  azure_service_principal {
    directory_id   = var.tenant_id
    application_id = var.client_id
    client_secret  = var.client_secret
  }
  
  comment = "Storage credential for ${each.key} environment"
}

resource "databricks_external_location" "data_lake" {
  for_each = local.unity_catalog_enabled ? toset(local.environments) : []
  
  name = "${each.key}_data_lake"
  url  = "abfss://data@${azurerm_storage_account.adls[each.key].name}.dfs.core.windows.net/"
  credential_name = databricks_storage_credential.external[each.key].name
  comment = "External location for ${each.key} data lake storage"
  
  depends_on = [databricks_storage_credential.external]
}

resource "databricks_grants" "external_location" {
  for_each = local.unity_catalog_enabled ? toset(local.environments) : []
  
  external_location = databricks_external_location.data_lake[each.key].name
  
  grant {
    principal  = databricks_group.data_engineers.display_name
    privileges = ["CREATE_EXTERNAL_TABLE", "READ_FILES", "WRITE_FILES"]
  }
  
  depends_on = [databricks_external_location.data_lake]
}
