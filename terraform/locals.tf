# Consolidated locals file for all environment configurations and shared variables

locals {
  # Environment definitions - use a variable to control which environments to deploy
  target_env = var.environment != "" ? [var.environment] : ["dev", "prod"]
  environments = var.deploy_all_environments ? ["dev", "prod"] : local.target_env
  
  # Environment-specific configurations
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
  
  # Machine Learning workspace configuration
  skip_ml_workspace = true  # Set to false after purging or recovering the soft-deleted workspaces
  
  # Unity Catalog configuration
  metastore_id = databricks_metastore.this.id
  
  # Cluster configurations
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
  
  # SQL Warehouse configurations
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
