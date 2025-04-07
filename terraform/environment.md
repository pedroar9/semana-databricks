# Environment Control Instructions

## Issue: Both Dev and Prod Resources Being Created

We've identified that the current Terraform configuration is creating resources for both development and production environments even when only the dev environment is specified. This happens because we're using a fixed list of environments in `locals.tf` rather than making it configurable.

## Solution: Update Your dev.tfvars File

We've modified the Terraform configuration to respect environment-specific deployments by adding two new variables:

1. `environment` - Specifies which environment to deploy (dev or prod)
2. `deploy_all_environments` - Controls whether to deploy all environments or just the specified one

To deploy only the dev environment, add these lines to your `dev.tfvars` file:

```hcl
environment = "dev"
deploy_all_environments = false
```

To deploy only the prod environment, add these lines to your `prod.tfvars` file:

```hcl
environment = "prod"
deploy_all_environments = false
```

To deploy both environments simultaneously, set:

```hcl
deploy_all_environments = true
```

## How to Apply These Changes

1. Add the above variables to your tfvars files
2. Stop the current deployment if it's still running
3. Run `terraform destroy` to clean up any partially created resources
4. Run the deployment again with the updated configuration:
   ```bash
   make local-dev-deploy-phase1
   ```

This will ensure that only the resources for the specified environment are created.
