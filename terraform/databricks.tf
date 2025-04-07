resource "azurerm_databricks_workspace" "this" {
  for_each = {
    for env in local.environments : env => local.env_config[env]
  }

  name                        = "${each.value.name_prefix}-workspace"
  resource_group_name         = azurerm_resource_group.this[each.key].name
  location                    = azurerm_resource_group.this[each.key].location
  sku                         = var.databricks_sku
  managed_resource_group_name = "${each.value.name_prefix}-databricks-managed-rg"
  tags                        = each.value.tags

  custom_parameters {
    no_public_ip                                         = var.no_public_ip
    virtual_network_id                                   = azurerm_virtual_network.this[each.key].id
    public_subnet_name                                   = azurerm_subnet.public[each.key].name
    private_subnet_name                                  = azurerm_subnet.private[each.key].name
    public_subnet_network_security_group_association_id  = azurerm_subnet_network_security_group_association.public[each.key].id
    private_subnet_network_security_group_association_id = azurerm_subnet_network_security_group_association.private[each.key].id
  }
}

resource "azurerm_application_insights" "ml" {
  for_each = var.enable_ml_integration ? toset(local.environments) : []

  name                = "${local.env_config[each.key].name_prefix}-ai"
  location            = azurerm_resource_group.this[each.key].location
  resource_group_name = azurerm_resource_group.this[each.key].name
  application_type    = "web"
  tags                = local.env_config[each.key].tags
}

resource "azurerm_machine_learning_workspace" "this" {
  for_each = var.enable_ml_integration && !local.skip_ml_workspace ? toset(local.environments) : []

  name                    = "${local.env_config[each.key].name_prefix}-ml-workspace"
  location                = azurerm_resource_group.this[each.key].location
  resource_group_name     = azurerm_resource_group.this[each.key].name
  application_insights_id = azurerm_application_insights.ml[each.key].id
  key_vault_id            = azurerm_key_vault.this[each.key].id
  storage_account_id      = azurerm_storage_account.ml[each.key].id
  
  identity {
    type = "SystemAssigned"
  }

  tags = local.env_config[each.key].tags
}

resource "databricks_cluster" "job_cluster" {
  for_each = {
    for env in local.environments : env => { config = local.env_config[env] }
  }

  cluster_name            = "${each.value.config.name_prefix}-job-cluster"
  spark_version           = var.spark_version
  node_type_id            = var.node_type_id
  autotermination_minutes = 20
  data_security_mode      = "SINGLE_USER"

  autoscale {
    min_workers = local.cluster_config[each.key].min_workers
    max_workers = local.cluster_config[each.key].max_workers
  }

  spark_conf = {
    "spark.databricks.cluster.profile" : "singleNode"
    "spark.master" : "local[*]"
  }

  custom_tags = {
    "ResourceClass" = "SingleNode"
    "Environment"   = each.key
  }
}

resource "databricks_sql_endpoint" "this" {
  for_each = {
    for env in local.environments : env => { config = local.env_config[env] }
  }

  name             = "${each.value.config.name_prefix}-sql-warehouse"
  cluster_size     = "Small"
  max_num_clusters = local.sql_warehouse_config[each.key].max_num_clusters
  min_num_clusters = local.sql_warehouse_config[each.key].min_num_clusters
  auto_stop_mins   = local.sql_warehouse_config[each.key].auto_stop_mins
  enable_photon    = true
}

resource "databricks_secret_scope" "this" {
  for_each = {
    for env in local.environments : env => { config = local.env_config[env] }
  }

  name = "${each.value.config.name_prefix}-scope"
}

resource "azurerm_application_insights" "monitoring" {
  for_each = var.enable_alerts ? toset(local.environments) : []

  name                = "${local.env_config[each.key].name_prefix}-appinsights"
  location            = azurerm_resource_group.this[each.key].location
  resource_group_name = azurerm_resource_group.this[each.key].name
  application_type    = "web"
  tags                = local.env_config[each.key].tags
}

resource "azurerm_monitor_action_group" "ops" {
  for_each = var.enable_alerts ? toset(local.environments) : []

  name                = "${local.env_config[each.key].name_prefix}-ops-action-group"
  resource_group_name = azurerm_resource_group.this[each.key].name
  short_name          = "${each.key}ops"

  email_receiver {
    name          = "ops-team"
    email_address = var.ops_email
    use_common_alert_schema = true
  }
}

resource "azurerm_monitor_diagnostic_setting" "databricks" {
  for_each = var.enable_monitoring ? toset(local.environments) : []

  name                       = "diag-${local.env_config[each.key].name_prefix}-databricks"
  target_resource_id         = azurerm_databricks_workspace.this[each.key].id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this[each.key].id
  
  log_analytics_destination_type = "Dedicated"
  
  enabled_log {
    category = "dbfs"
  }
  
  enabled_log {
    category = "clusters"
  }
  
  enabled_log {
    category = "accounts"
  }
  
  enabled_log {
    category = "jobs"
  }
  
  enabled_log {
    category = "notebook"
  }
  
  enabled_log {
    category = "workspace"
  }
  
  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

resource "azurerm_monitor_diagnostic_setting" "storage" {
  for_each = var.enable_monitoring ? toset(local.environments) : []

  name                       = "diag-${local.env_config[each.key].name_prefix}-storage"
  target_resource_id         = azurerm_storage_account.adls[each.key].id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this[each.key].id
  
  metric {
    category = "Transaction"
    enabled  = true
  }
  
  metric {
    category = "Capacity"
    enabled  = true
  }
}

resource "azurerm_log_analytics_workspace" "this" {
  for_each = var.enable_monitoring ? toset(local.environments) : []

  name                = "${local.env_config[each.key].name_prefix}-law"
  location            = azurerm_resource_group.this[each.key].location
  resource_group_name = azurerm_resource_group.this[each.key].name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.env_config[each.key].tags
}
