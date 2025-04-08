DEV_WORKSPACE_URL=$(terraform output -json databricks_workspace_urls | jq -r '.dev // ""')
PROD_WORKSPACE_URL=$(terraform output -json databricks_workspace_urls | jq -r '.prod // ""')

if [ -n "$PROD_WORKSPACE_URL" ]; then
  WORKSPACE_URL=$PROD_WORKSPACE_URL
  ENV="prod"
elif [ -n "$DEV_WORKSPACE_URL" ]; then
  WORKSPACE_URL=$DEV_WORKSPACE_URL
  ENV="dev"
else
  echo "Error: No workspace URL found in Terraform output"
  exit 1
fi

echo "databricks_host = \"https://$WORKSPACE_URL\"" > workspace.auto.tfvars
echo "Workspace URL configured for $ENV environment: https://$WORKSPACE_URL"
