resource "databricks_group" "data_engineers" {
  for_each = {
    dev  = "dev"
    prod = "prod"
  }


  display_name = "data-engineers"
}

resource "databricks_group" "data_scientists" {
  for_each = {
    dev  = "dev"
    prod = "prod"
  }


  display_name = "data-scientists"
}

resource "databricks_group" "analysts" {
  for_each = {
    dev  = "dev"
    prod = "prod"
  }


  display_name = "analysts"
}

resource "databricks_service_principal" "automation" {
  for_each = {
    dev  = "dev"
    prod = "prod"
  }


  display_name = "${local.env_config[each.key].name_prefix}-automation-sp"
  allow_cluster_create = true
}

resource "databricks_permissions" "cluster_usage" {
  for_each = {
    dev = {
      cluster_id = databricks_cluster.shared_autoscaling["dev"].id
    }
    prod = {
      cluster_id = databricks_cluster.shared_autoscaling["prod"].id
    }
  }


  cluster_id = each.value.cluster_id

  access_control {
    group_name       = databricks_group.data_engineers[each.key].display_name
    permission_level = "CAN_RESTART"
  }

  access_control {
    group_name       = databricks_group.data_scientists[each.key].display_name
    permission_level = "CAN_ATTACH_TO"
  }
}

resource "databricks_permissions" "sql_warehouse" {
  for_each = {
    dev = {
      warehouse_id = databricks_sql_endpoint.analytics["dev"].id
    }
    prod = {
      warehouse_id = databricks_sql_endpoint.analytics["prod"].id
    }
  }


  sql_endpoint_id = each.value.warehouse_id

  access_control {
    group_name       = databricks_group.analysts[each.key].display_name
    permission_level = "CAN_USE"
  }
}

resource "databricks_grants" "catalog" {
  for_each = {
    for pair in setproduct(["dev", "prod"], ["ubereats_operations", "ubereats_finance", "ubereats_ml"]) : "${pair[0]}-${pair[1]}" => {
      env    = pair[0]
      domain = pair[1]
    }
  }


  catalog = databricks_catalog.domains["${each.value.env}-${each.value.domain}"].name

  grant {
    principal  = databricks_group.data_engineers[each.value.env].display_name
    privileges = ["USE_CATALOG", "CREATE", "MODIFY"]
  }

  grant {
    principal  = databricks_group.data_scientists[each.value.env].display_name
    privileges = ["USE_CATALOG", "SELECT"]
  }

  grant {
    principal  = databricks_group.analysts[each.value.env].display_name
    privileges = ["USE_CATALOG", "SELECT"]
  }
}

resource "azurerm_private_endpoint" "databricks_ui" {
  for_each = var.enable_private_endpoints ? toset(local.environments) : []

  name                = "${local.env_config[each.key].name_prefix}-dbx-ui-pe"
  location            = azurerm_resource_group.this[each.key].location
  resource_group_name = azurerm_resource_group.this[each.key].name
  subnet_id           = azurerm_subnet.private[each.key].id

  private_service_connection {
    name                           = "${local.env_config[each.key].name_prefix}-dbx-ui-psc"
    private_connection_resource_id = data.azurerm_databricks_workspace.existing[each.key].id
    is_manual_connection           = false
    subresource_names              = ["databricks_ui_api"]
  }

  tags = local.env_config[each.key].tags
}

resource "azurerm_private_endpoint" "databricks_auth" {
  for_each = var.enable_private_endpoints ? toset(local.environments) : []

  name                = "${local.env_config[each.key].name_prefix}-dbx-auth-pe"
  location            = azurerm_resource_group.this[each.key].location
  resource_group_name = azurerm_resource_group.this[each.key].name
  subnet_id           = azurerm_subnet.private[each.key].id

  private_service_connection {
    name                           = "${local.env_config[each.key].name_prefix}-dbx-auth-psc"
    private_connection_resource_id = data.azurerm_databricks_workspace.existing[each.key].id
    is_manual_connection           = false
    subresource_names              = ["databricks_ui_auth"]
  }

  tags = local.env_config[each.key].tags
}

resource "databricks_ip_access_list" "allowed" {
  for_each = {
    dev  = "dev"
    prod = "prod"
  }


  label                   = "allowed_ips"
  list_type               = "ALLOW"
  ip_addresses            = var.bypass_ip_ranges

}

resource "azurerm_key_vault_key" "dbfs_encryption" {
  count = var.enable_customer_managed_keys ? 1 : 0

  name         = "dbfs-encryption-key"
  key_vault_id = azurerm_key_vault.this["prod"].id
  key_type     = "RSA"
  key_size     = 2048

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]
}

output "service_principal_ids" {
  value = {
    for env in local.environments : env => databricks_service_principal.automation[env].application_id
  }
  description = "Service principal IDs for automation"
}