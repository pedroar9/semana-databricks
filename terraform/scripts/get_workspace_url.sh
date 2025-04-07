WORKSPACE_URL=$(terraform output -json databricks_workspace_urls | jq -r '.dev')

echo "databricks_host = \"https://$WORKSPACE_URL\"" > workspace.auto.tfvars
echo "Workspace URL configured: https://$WORKSPACE_URL"
