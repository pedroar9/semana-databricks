resource "azurerm_resource_group" "this" {
  for_each = {
    dev  = local.env_config.dev
    prod = local.env_config.prod
  }

  name     = "${each.value.name_prefix}-rg"
  location = each.value.location
  tags     = each.value.tags
}

resource "azurerm_virtual_network" "this" {
  for_each = {
    dev  = local.env_config.dev
    prod = local.env_config.prod
  }

  name                = "${each.value.name_prefix}-vnet"
  location            = azurerm_resource_group.this[each.key].location
  resource_group_name = azurerm_resource_group.this[each.key].name
  address_space       = ["10.0.0.0/16"]
  tags                = each.value.tags
}

resource "azurerm_network_security_group" "databricks" {
  for_each = {
    dev  = local.env_config.dev
    prod = local.env_config.prod
  }

  name                = "${each.value.name_prefix}-nsg"
  location            = azurerm_resource_group.this[each.key].location
  resource_group_name = azurerm_resource_group.this[each.key].name
  tags                = each.value.tags
}

resource "azurerm_subnet" "public" {
  for_each = {
    dev  = local.env_config.dev
    prod = local.env_config.prod
  }

  name                 = "${each.value.name_prefix}-public-subnet"
  resource_group_name  = azurerm_resource_group.this[each.key].name
  virtual_network_name = azurerm_virtual_network.this[each.key].name
  address_prefixes     = ["10.0.1.0/24"]

  delegation {
    name = "databricks-delegation"

    service_delegation {
      name = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"
      ]
    }
  }
}

resource "azurerm_subnet" "private" {
  for_each = {
    dev  = local.env_config.dev
    prod = local.env_config.prod
  }

  name                 = "${each.value.name_prefix}-private-subnet"
  resource_group_name  = azurerm_resource_group.this[each.key].name
  virtual_network_name = azurerm_virtual_network.this[each.key].name
  address_prefixes     = ["10.0.2.0/24"]

  delegation {
    name = "databricks-delegation"

    service_delegation {
      name = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"
      ]
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "public" {
  for_each = {
    dev  = local.env_config.dev
    prod = local.env_config.prod
  }

  subnet_id                 = azurerm_subnet.public[each.key].id
  network_security_group_id = azurerm_network_security_group.databricks[each.key].id
}

resource "azurerm_subnet_network_security_group_association" "private" {
  for_each = {
    dev  = local.env_config.dev
    prod = local.env_config.prod
  }

  subnet_id                 = azurerm_subnet.private[each.key].id
  network_security_group_id = azurerm_network_security_group.databricks[each.key].id
}

resource "azurerm_storage_account" "adls" {
  for_each = {
    dev  = local.env_config.dev
    prod = local.env_config.prod
  }

  name                     = "adls${replace(each.value.name_prefix, "-", "")}"
  resource_group_name      = azurerm_resource_group.this[each.key].name
  location                 = azurerm_resource_group.this[each.key].location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true
  tags                     = each.value.tags
}

resource "azurerm_storage_data_lake_gen2_filesystem" "this" {
  for_each = {
    for pair in setproduct(local.environments, ["landing", "bronze", "silver", "gold"]) : "${pair[0]}-${pair[1]}" => {
      env  = pair[0]
      zone = pair[1]
    }
  }

  name               = each.value.zone
  storage_account_id = azurerm_storage_account.adls[each.value.env].id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "unity_catalog" {
  name               = "unity-catalog"
  storage_account_id = azurerm_storage_account.adls["prod"].id
}

resource "azurerm_key_vault" "this" {
  for_each = {
    dev  = local.env_config.dev
    prod = local.env_config.prod
  }

  name                        = "${each.value.name_prefix}-kv"
  location                    = azurerm_resource_group.this[each.key].location
  resource_group_name         = azurerm_resource_group.this[each.key].name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  sku_name                    = "standard"
  tags                        = each.value.tags

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get", "List", "Create", "Delete", "Update",
    ]

    secret_permissions = [
      "Get", "List", "Set", "Delete",
    ]
  }
}

resource "azurerm_storage_account" "ml" {
  for_each = var.enable_ml_integration ? toset(local.environments) : []

  name                     = "ml${replace(local.env_config[each.key].name_prefix, "-", "")}"
  resource_group_name      = azurerm_resource_group.this[each.key].name
  location                 = azurerm_resource_group.this[each.key].location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = local.env_config[each.key].tags
}

data "azurerm_client_config" "current" {}
