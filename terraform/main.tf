terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.75.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.28.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5.0"
    }
  }
  required_version = ">= 1.2.0"
  
  backend "local" {}
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
  
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
}

locals {
  environments = ["dev", "prod"]

  common_tags = {
    Project     = "UberEats-Databricks"
    ManagedBy   = "Terraform"
    Application = "Data Intelligence Platform"
  }

  env_config = {
    dev = {
      location      = var.location
      name_prefix   = "${var.prefix}-dev"
      tags          = merge(local.common_tags, { Environment = "Development" })
      sku           = "premium"
      node_type     = "Standard_DS3_v2"
      min_workers   = 2
      max_workers   = 8
      autotermination_minutes = 20
      spark_version = "11.3.x-scala2.12"
    }
    prod = {
      location      = var.location
      name_prefix   = "${var.prefix}-prod"
      tags          = merge(local.common_tags, { Environment = "Production" })
      sku           = "premium"
      node_type     = "Standard_DS4_v2"
      min_workers   = 4
      max_workers   = 16
      autotermination_minutes = 120
      spark_version = "11.3.x-scala2.12"
    }
  }
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_resource_group" "this" {
  for_each = toset(local.environments)

  name     = "${local.env_config[each.key].name_prefix}-rg-${random_string.suffix.result}"
  location = local.env_config[each.key].location
  tags     = local.env_config[each.key].tags
}

resource "azurerm_network_security_group" "databricks" {
  for_each = toset(local.environments)

  name                = "${local.env_config[each.key].name_prefix}-databricks-nsg"
  location            = azurerm_resource_group.this[each.key].location
  resource_group_name = azurerm_resource_group.this[each.key].name
  tags                = local.env_config[each.key].tags
}

resource "azurerm_virtual_network" "this" {
  for_each = toset(local.environments)

  name                = "${local.env_config[each.key].name_prefix}-vnet"
  location            = azurerm_resource_group.this[each.key].location
  resource_group_name = azurerm_resource_group.this[each.key].name
  address_space       = ["10.${each.key == "prod" ? "0" : "1"}.0.0/16"]
  tags                = local.env_config[each.key].tags
}

resource "azurerm_subnet" "public" {
  for_each = toset(local.environments)

  name                 = "${local.env_config[each.key].name_prefix}-public-subnet"
  resource_group_name  = azurerm_resource_group.this[each.key].name
  virtual_network_name = azurerm_virtual_network.this[each.key].name
  address_prefixes     = ["10.${each.key == "prod" ? "0" : "1"}.1.0/24"]

  delegation {
    name = "databricks-delegation"
    service_delegation {
      name = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action",
      ]
    }
  }
}

resource "azurerm_subnet" "private" {
  for_each = toset(local.environments)

  name                 = "${local.env_config[each.key].name_prefix}-private-subnet"
  resource_group_name  = azurerm_resource_group.this[each.key].name
  virtual_network_name = azurerm_virtual_network.this[each.key].name
  address_prefixes     = ["10.${each.key == "prod" ? "0" : "1"}.2.0/24"]

  delegation {
    name = "databricks-delegation"
    service_delegation {
      name = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action",
      ]
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "public" {
  for_each = toset(local.environments)

  subnet_id                 = azurerm_subnet.public[each.key].id
  network_security_group_id = azurerm_network_security_group.databricks[each.key].id
}

resource "azurerm_subnet_network_security_group_association" "private" {
  for_each = toset(local.environments)

  subnet_id                 = azurerm_subnet.private[each.key].id
  network_security_group_id = azurerm_network_security_group.databricks[each.key].id
}

resource "azurerm_databricks_workspace" "this" {
  for_each = toset(local.environments)

  name                = "${local.env_config[each.key].name_prefix}-workspace"
  resource_group_name = azurerm_resource_group.this[each.key].name
  location            = azurerm_resource_group.this[each.key].location
  sku                 = local.env_config[each.key].sku
  tags                = local.env_config[each.key].tags

  custom_parameters {
    no_public_ip                                         = false
    virtual_network_id                                   = azurerm_virtual_network.this[each.key].id
    private_subnet_name                                  = azurerm_subnet.private[each.key].name
    public_subnet_name                                   = azurerm_subnet.public[each.key].name
    public_subnet_network_security_group_association_id  = azurerm_subnet_network_security_group_association.public[each.key].id
    private_subnet_network_security_group_association_id = azurerm_subnet_network_security_group_association.private[each.key].id
  }
}

resource "azurerm_key_vault" "this" {
  for_each = toset(local.environments)

  name                     = "${local.env_config[each.key].name_prefix}-kv-${random_string.suffix.result}"
  location                 = azurerm_resource_group.this[each.key].location
  resource_group_name      = azurerm_resource_group.this[each.key].name
  tenant_id                = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days = 7
  purge_protection_enabled = false
  sku_name                 = "standard"
  tags                     = local.env_config[each.key].tags

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

resource "azurerm_storage_account" "adls" {
  for_each = toset(local.environments)

  name                     = "adls${replace(local.env_config[each.key].name_prefix, "-", "")}${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.this[each.key].name
  location                 = azurerm_resource_group.this[each.key].location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true
  tags                     = local.env_config[each.key].tags

  blob_properties {
    cors_rule {
      allowed_headers    = ["*"]
      allowed_methods    = ["GET", "HEAD", "POST", "PUT"]
      allowed_origins    = ["https://*.azuredatabricks.net"]
      exposed_headers    = ["*"]
      max_age_in_seconds = 3600
    }
  }

  network_rules {
    default_action = "Allow"
    bypass         = ["AzureServices"]
  }
}

resource "azurerm_storage_data_lake_gen2_filesystem" "this" {
  for_each = {
    for pair in setproduct(local.environments, ["bronze", "silver", "gold", "landing"]) : "${pair[0]}-${pair[1]}" => {
      env  = pair[0]
      zone = pair[1]
    }
  }

  name               = each.value.zone
  storage_account_id = azurerm_storage_account.adls[each.value.env].id
}

data "azurerm_client_config" "current" {}



resource "databricks_cluster" "shared_autoscaling" {
  for_each = {
    dev  = { config = local.env_config.dev }
    prod = { config = local.env_config.prod }
  }



  cluster_name            = "${each.value.config.name_prefix}-shared-cluster"
  spark_version           = each.value.config.spark_version
  node_type_id            = each.value.config.node_type
  autotermination_minutes = each.value.config.autotermination_minutes

  autoscale {
    min_workers = each.value.config.min_workers
    max_workers = each.value.config.max_workers
  }

  spark_conf = {
    "spark.databricks.delta.preview.enabled" : "true",
    "spark.databricks.io.cache.enabled" : "true",
    "spark.sql.adaptive.enabled" : "true"
  }

  custom_tags = each.value.config.tags
}

resource "databricks_cluster" "data_science" {
  for_each = {
    dev  = { config = local.env_config.dev }
    prod = { config = local.env_config.prod }
  }



  cluster_name            = "${each.value.config.name_prefix}-data-science-cluster"
  spark_version           = each.value.config.spark_version
  node_type_id            = each.value.config.node_type
  autotermination_minutes = each.value.config.autotermination_minutes

  autoscale {
    min_workers = each.value.config.min_workers
    max_workers = each.value.config.max_workers
  }

  spark_conf = {
    "spark.databricks.delta.preview.enabled" : "true",
    "spark.databricks.io.cache.enabled" : "true",
    "spark.sql.adaptive.enabled" : "true"
  }

  custom_tags = merge(each.value.config.tags, {
    Purpose = "DataScience"
  })

  library {
    pypi {
      package = "scikit-learn"
    }
  }

  library {
    pypi {
      package = "xgboost"
    }
  }
}

resource "databricks_sql_endpoint" "analytics" {
  for_each = {
    dev  = { config = local.env_config.dev }
    prod = { config = local.env_config.prod }
  }



  name             = "${each.value.config.name_prefix}-sql-warehouse"
  cluster_size     = each.key == "prod" ? "Medium" : "Small"
  max_num_clusters = each.key == "prod" ? 2 : 1
  auto_stop_mins   = each.key == "prod" ? 60 : 30
}

resource "databricks_metastore" "this" {
  for_each = {
    dev  = { config = local.env_config.dev }
    prod = { config = local.env_config.prod }
  }



  name = "${each.value.config.name_prefix}-unity-catalog"
  storage_root = "abfss://unity-catalog@${azurerm_storage_account.adls[each.key].name}.dfs.core.windows.net/"
  owner = "admins"
}

resource "databricks_catalog" "domains" {
  for_each = {
    for pair in setproduct(["dev", "prod"], ["ubereats_operations", "ubereats_finance", "ubereats_ml"]) : "${pair[0]}-${pair[1]}" => {
      env    = pair[0]
      domain = pair[1]
      config = local.env_config[pair[0]]
    }
  }



  metastore_id = databricks_metastore.this[each.value.env].id
  name         = each.value.domain
  comment      = "Catalog for ${each.value.domain} domain"
}

resource "databricks_schema" "medallion" {
  for_each = {
    for entry in setproduct(
      ["dev", "prod"],
      ["ubereats_operations", "ubereats_finance", "ubereats_ml"],
      ["bronze", "silver", "gold"]
    ) : "${entry[0]}-${entry[1]}-${entry[2]}" => {
      env     = entry[0]
      domain  = entry[1]
      zone    = entry[2]
    }
  }



  catalog_name = databricks_catalog.domains["${each.value.env}-${each.value.domain}"].name
  name         = each.value.zone
  comment      = "${each.value.zone} layer for ${each.value.domain}"
}

resource "databricks_secret_scope" "this" {
  for_each = {
    dev  = "dev"
    prod = "prod"
  }



  name                     = "${local.env_config[each.key].name_prefix}-secret-scope"
  initial_manage_principal = "users"
}


resource "databricks_directory" "project_structure" {
  for_each = {
    for pair in setproduct(
      ["dev", "prod"],
      ["01-ingest", "02-transform", "03-serve", "04-ml", "05-genai"]
    ) : "${pair[0]}-${pair[1]}" => {
      env     = pair[0]
      folder  = pair[1]
    }
  }



  path = "/Shared/${each.value.folder}"
}

resource "databricks_cluster_policy" "data_engineering" {
  for_each = {
    dev  = "dev"
    prod = "prod"
  }



  name = "${local.env_config[each.key].name_prefix}-data-engineering-policy"

  definition = jsonencode({
    "spark_version": {
      "type": "fixed",
      "value": local.env_config[each.key].spark_version
    },
    "node_type_id": {
      "type": "allowlist",
      "values": [local.env_config[each.key].node_type]
    },
    "autotermination_minutes": {
      "type": "fixed",
      "value": local.env_config[each.key].autotermination_minutes
    },
    "spark_conf.spark.databricks.cluster.profile": {
      "type": "fixed",
      "value": "singleNode"
    },
    "custom_tags.Project": {
      "type": "fixed",
      "value": "UberEats-Databricks"
    }
  })
}

output "databricks_urls" {
  value = {
    for env in local.environments : env => azurerm_databricks_workspace.this[env].workspace_url
  }
  description = "URLs of the Databricks workspaces"
}

output "storage_account_names" {
  value = {
    for env in local.environments : env => azurerm_storage_account.adls[env].name
  }
  description = "Names of the storage accounts"
}

output "key_vault_names" {
  value = {
    for env in local.environments : env => azurerm_key_vault.this[env].name
  }
  description = "Names of the Key Vaults"
}