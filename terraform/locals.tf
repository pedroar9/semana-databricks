locals {
  environments = var.deploy_all_environments ? ["dev", "prod"] : (var.environment != "" ? [var.environment] : ["dev"])  
  env_config = {
    dev = {
      name_prefix = "ubereats-dev"
      location    = "eastus2"
      tags        = { Environment = "Development", Project = "UberEats" }
    }
    prod = {
      name_prefix = "ubereats-prod"
      location    = "eastus2"
      tags        = { Environment = "Production", Project = "UberEats" }
    }
  }
  
  skip_ml_workspace = true
  
  unity_catalog_enabled = false 
  metastore_id = ""
  cluster_config = {
    dev = {
      min_workers = 1
      max_workers = 5
    }
    prod = {
      min_workers = 2
      max_workers = 5
    }
  }
  
  sql_warehouse_config = {
    dev = {
      auto_stop_mins = 10
      min_num_clusters = 1
      max_num_clusters = 2
    }
    prod = {
      auto_stop_mins = 30
      min_num_clusters = 1
      max_num_clusters = 3
    }
  }
}
