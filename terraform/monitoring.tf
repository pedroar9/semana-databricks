resource "azurerm_log_analytics_workspace" "this" {
  for_each = var.enable_alerts ? toset(local.environments) : []

  name                = "${local.env_config[each.key].name_prefix}-laws"
  location            = azurerm_resource_group.this[each.key].location
  resource_group_name = azurerm_resource_group.this[each.key].name
  sku                 = "PerGB2018"
  retention_in_days   = each.key == "prod" ? 90 : 30
  tags                = local.env_config[each.key].tags
}

resource "azurerm_monitor_diagnostic_setting" "databricks" {
  for_each = var.enable_alerts ? toset(local.environments) : []

  name                       = "diag-${local.env_config[each.key].name_prefix}-databricks"
  target_resource_id         = azurerm_databricks_workspace.this[each.key].id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this[each.key].id

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


}

resource "azurerm_monitor_diagnostic_setting" "storage" {
  for_each = var.enable_alerts ? toset(local.environments) : []

  name                       = "diag-${local.env_config[each.key].name_prefix}-storage"
  target_resource_id         = azurerm_storage_account.adls[each.key].id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this[each.key].id

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
resource "azurerm_monitor_action_group" "ops" {
  for_each = var.enable_alerts ? toset(local.environments) : []

  name                = "${local.env_config[each.key].name_prefix}-ops-action-group"
  resource_group_name = azurerm_resource_group.this[each.key].name
  short_name          = "ops-alerts"

  email_receiver {
    name                    = "ops-team"
    email_address           = "ops-team@example.com"
    use_common_alert_schema = true
  }

  tags = local.env_config[each.key].tags
}

resource "azurerm_application_insights" "monitoring" {
  for_each = var.enable_alerts ? toset(local.environments) : []

  name                = "${local.env_config[each.key].name_prefix}-appinsights"
  location            = azurerm_resource_group.this[each.key].location
  resource_group_name = azurerm_resource_group.this[each.key].name
  application_type    = "web"
  tags                = local.env_config[each.key].tags
}

output "app_insights_instrumentation_key" {
  value = {
    for env in local.environments : env => var.enable_alerts ? azurerm_application_insights.monitoring[env].instrumentation_key : null
  }
  description = "Application Insights instrumentation key for Databricks monitoring"
  sensitive   = true
}
