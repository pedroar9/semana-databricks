resource "azurerm_machine_learning_workspace" "this" {
  for_each = var.enable_ml_integration ? toset(local.environments) : []

  name                    = "${local.env_config[each.key].name_prefix}-ml-workspace"
  location                = azurerm_resource_group.this[each.key].location
  resource_group_name     = azurerm_resource_group.this[each.key].name
  application_insights_id = data.azurerm_application_insights.existing[each.key].id
  key_vault_id            = azurerm_key_vault.this[each.key].id
  storage_account_id      = azurerm_storage_account.ml[each.key].id
  
  identity {
    type = "SystemAssigned"
  }

  tags = local.env_config[each.key].tags
}

data "azurerm_application_insights" "existing" {
  for_each = var.enable_ml_integration ? toset(local.environments) : []

  name                = "${local.env_config[each.key].name_prefix}-ai"
  resource_group_name = azurerm_resource_group.this[each.key].name
}

resource "azurerm_storage_account" "ml" {
  for_each = var.enable_ml_integration ? toset(local.environments) : []

  name                     = "ml${replace(local.env_config[each.key].name_prefix, "-", "")}${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.this[each.key].name
  location                 = azurerm_resource_group.this[each.key].location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = local.env_config[each.key].tags
}
