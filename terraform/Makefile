DEV_VARS := -var-file=dev.tfvars
PROD_VARS := -var-file=prod.tfvars
CORE_TARGETS := -target=azurerm_resource_group.this -target=azurerm_virtual_network.this -target=azurerm_subnet.public -target=azurerm_subnet.private -target=azurerm_databricks_workspace.this
STORAGE_TARGETS := -target=azurerm_storage_account.adls -target=azurerm_storage_data_lake_gen2_filesystem.this

TF_ORG := engenharia-academy
TF_WORKSPACE := databricks-platform

.PHONY: login
login:
	terraform login

.PHONY: init
init: login
	terraform init

.PHONY: dev-plan-core
dev-plan-core: init
	terraform plan $(DEV_VARS) $(CORE_TARGETS)

.PHONY: dev-apply-core
dev-apply-core: dev-plan-core
	terraform apply $(DEV_VARS) $(CORE_TARGETS)

.PHONY: dev-plan-storage
dev-plan-storage: dev-apply-core
	terraform plan $(DEV_VARS) $(STORAGE_TARGETS)

.PHONY: dev-apply-storage
dev-apply-storage: dev-plan-storage
	terraform apply $(DEV_VARS) $(STORAGE_TARGETS)

.PHONY: dev-plan-databricks
dev-plan-databricks: dev-apply-storage
	terraform plan $(DEV_VARS)

.PHONY: dev-apply-databricks
dev-apply-databricks: dev-plan-databricks
	terraform apply $(DEV_VARS)

.PHONY: dev-deploy
dev-deploy: dev-apply-databricks
	@echo "Development environment deployment complete"

.PHONY: prod-plan-core
prod-plan-core: init
	terraform plan $(PROD_VARS) $(CORE_TARGETS)

.PHONY: prod-apply-core
prod-apply-core: prod-plan-core
	terraform apply $(PROD_VARS) $(CORE_TARGETS)

.PHONY: prod-plan-storage
prod-plan-storage: prod-apply-core
	terraform plan $(PROD_VARS) $(STORAGE_TARGETS)

.PHONY: prod-apply-storage
prod-apply-storage: prod-plan-storage
	terraform apply $(PROD_VARS) $(STORAGE_TARGETS)

.PHONY: prod-plan-databricks
prod-plan-databricks: prod-apply-storage
	terraform plan $(PROD_VARS)

.PHONY: prod-apply-databricks
prod-apply-databricks: prod-plan-databricks
	terraform apply $(PROD_VARS)

.PHONY: prod-deploy
prod-deploy: prod-apply-databricks
	@echo "Production environment deployment complete"

.PHONY: dev-destroy
dev-destroy:
	terraform destroy $(DEV_VARS)

.PHONY: prod-destroy
prod-destroy:
	terraform destroy $(PROD_VARS)

.PHONY: local-mode
local-mode:
	@echo "Setting up for local execution..."
	rm -f .terraform/terraform.tfstate
	rm -rf .terraform/providers

.PHONY: set-azure-credentials
set-azure-credentials:
	@echo "Please set the following environment variables before running this command:"
	@echo "export ARM_CLIENT_ID=\"your-client-id\""
	@echo "export ARM_CLIENT_SECRET=\"your-client-secret\""
	@echo "export ARM_TENANT_ID=\"your-tenant-id\""
	@echo "export ARM_SUBSCRIPTION_ID=\"your-subscription-id\""

.PHONY: local-init
local-init: local-mode set-azure-credentials
	terraform init

.PHONY: local-dev-deploy
local-dev-deploy: local-mode
	@echo "Running deployment in local mode with credentials from credentials.auto.tfvars..."
	terraform init
	terraform plan $(DEV_VARS)
	@echo "Review the plan above. Type 'yes' to apply or Ctrl+C to cancel."
	terraform apply $(DEV_VARS)

.PHONY: local-prod-deploy
local-prod-deploy: local-mode
	@echo "Running deployment in local mode with Azure credentials..."
	terraform init -force-copy
	terraform apply $(PROD_VARS) -auto-approve

.PHONY: cloud-mode
cloud-mode:
	@echo "Setting up for Terraform Cloud execution..."
	@echo "Using organization: $(TF_ORG) and workspace: $(TF_WORKSPACE)"
	rm -f backend.tf
	sed -e 's/backend "local" {}/cloud {
    organization = "$(TF_ORG)"
    
    workspaces {
      name = "$(TF_WORKSPACE)"
    }
  }/' main.tf > main.tf.tmp && mv main.tf.tmp main.tf

.PHONY: cloud-init
cloud-init: cloud-mode login
	terraform init -reconfigure

.PHONY: cloud-dev-deploy
cloud-dev-deploy: cloud-init
	@echo "Running deployment in Terraform Cloud mode with dev variables..."
	terraform plan $(DEV_VARS)
	@echo "Review the plan above. Type 'yes' to apply or Ctrl+C to cancel."
	terraform apply $(DEV_VARS)

.PHONY: cloud-prod-deploy
cloud-prod-deploy: cloud-init
	@echo "Running deployment in Terraform Cloud mode with prod variables..."
	terraform plan $(PROD_VARS)
	@echo "Review the plan above. Type 'yes' to apply or Ctrl+C to cancel."
	terraform apply $(PROD_VARS)

.PHONY: azure-backend
azure-backend:
	./azure-backend.sh


.PHONY: help
help:
	@echo "Available targets:"
	@echo "  init              - Initialize Terraform"
	@echo "  login             - Login to Terraform Cloud"
	@echo "  dev-deploy        - Deploy complete development environment"
	@echo "  local-dev-deploy  - Deploy development environment in local mode"
	@echo "  local-prod-deploy - Deploy production environment in local mode"
	@echo "  cloud-dev-deploy  - Deploy development environment in Terraform Cloud"
	@echo "  cloud-prod-deploy - Deploy production environment in Terraform Cloud"
	@echo "  prod-deploy       - Deploy complete production environment"
	@echo "  dev-destroy       - Destroy development environment"
	@echo "  prod-destroy      - Destroy production environment"
	@echo "  azure-backend     - Set up Azure Storage backend"
	@echo "  local-mode        - Set Terraform to run in local mode"
	@echo "  cloud-mode        - Set Terraform to run in Terraform Cloud mode"
	@echo ""
	@echo "Individual phase targets are also available:"
	@echo "  dev-plan-core, dev-apply-core, dev-plan-storage, dev-apply-storage, etc."
