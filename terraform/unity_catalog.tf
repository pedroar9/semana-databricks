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
