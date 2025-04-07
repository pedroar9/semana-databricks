echo "Creating resource group..."
az group create --name tfstate-rg --location eastus2

STORAGE_ACCOUNT="tfstate$(date +%s)"
echo "Creating storage account: $STORAGE_ACCOUNT"
az storage account create --name $STORAGE_ACCOUNT --resource-group tfstate-rg --sku Standard_LRS

echo "Getting storage account key..."
STORAGE_KEY=$(az storage account keys list --resource-group tfstate-rg --account-name $STORAGE_ACCOUNT --query [0].value -o tsv)

echo "Creating storage container..."
az storage container create --name tfstate --account-name $STORAGE_ACCOUNT --account-key "$STORAGE_KEY"

echo ""
echo "=== Terraform Backend Configuration ==="
echo "resource_group_name  = \"tfstate-rg\""
echo "storage_account_name = \"$STORAGE_ACCOUNT\""
echo "container_name       = \"tfstate\""
echo "key                  = \"databricks.terraform.tfstate\""