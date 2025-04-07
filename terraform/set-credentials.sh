echo "Setting Azure credentials as environment variables..."

export ARM_CLIENT_ID="$1"
export ARM_CLIENT_SECRET="$2"
export ARM_TENANT_ID="$3"
export ARM_SUBSCRIPTION_ID="$4"

echo "Azure credentials set successfully!"
echo "Client ID: ${ARM_CLIENT_ID}"
echo "Tenant ID: ${ARM_TENANT_ID}"
echo "Subscription ID: ${ARM_SUBSCRIPTION_ID}"
echo "Client Secret: [HIDDEN]"
