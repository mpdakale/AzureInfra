#!/bin/bash

# Script to create a Service Principal and assign a custom role at the resource group level for Terraform access
# Usage: ./create-terraform-sp.sh

# Service principal credential secret will be shown only once when it is created. If you re-run this script, it will show null.

# Define constants
PROJECT_NAME="netappcdmt"
ROLE_NAME="${PROJECT_NAME}-terraform-role"
ROLE_DESCRIPTION="Custom role for Terraform with specific permissions."
EXPIRATION_YEARS=3
SP_NAME="${PROJECT_NAME}-terraform-principal"

# Function to display help
function display_help {
  echo "Usage: $0"
  echo ""
  echo "Parameters:"
  echo "  None"
  echo ""
  echo "Examples:"
  echo "  $0"
  echo ""
  exit 0
}

# Check if help is requested
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  display_help
fi

# Check if Azure CLI is logged in
if ! az account show > /dev/null 2>&1; then
  echo "Azure CLI is not logged in. Please run 'az login' to authenticate."
  echo "Follow the instructions to complete the login process."
  exit 1
fi

# Display current Azure account details
echo "Currently logged in account details:"
az account show --query "{Name:name, SubscriptionId:id, TenantId:tenantId}" --output table

# Prompt user for confirmation of the correct account
read -p "Is this the correct account? (yes/no): " response
case "$response" in
  [Yy]*)
    echo "Proceeding with resource creation..."
    ;;
  [Nn]*)
    echo "Exiting script. Please run 'az login' with the correct account."
    exit 1
    ;;
  *)
    echo "Invalid response. Exiting script."
    exit 1
    ;;
esac

# Define permissions based on your requirements
SUBSCRIPTION_ID=$(az account show --query "id" --output tsv)

ROLE_PERMISSIONS='{
    "Name": "'"$ROLE_NAME"'",
    "Description": "'"$ROLE_DESCRIPTION"'",
    "Actions": [
        "Microsoft.Network/*",
        "Microsoft.Compute/*",
        "Microsoft.ContainerRegistry/registries/*",
        "Microsoft.Authorization/*",
        "Microsoft.Storage/*",
        "Microsoft.KeyVault/vaults/*",
        "Microsoft.KeyVault/*",
        "Microsoft.ManagedIdentity/userAssignedIdentities/*",
        "Microsoft.Insights/autoScaleSettings/*",
        "Microsoft.NetApp/netAppAccounts/*",
        "Microsoft.ContainerService/*"
    ],
    "NotActions": [],
    "AssignableScopes": ["/subscriptions/'$SUBSCRIPTION_ID'"]
}'

# Create the custom role if it doesn't exist
echo "Checking if custom role $ROLE_NAME exists..."
ROLE_ID=$(az role definition list --query "[?roleName=='$ROLE_NAME'].id" --output tsv)
if [ -z "$ROLE_ID" ]; then
    echo "Creating custom role: $ROLE_NAME..."
    az role definition create --role-definition "$ROLE_PERMISSIONS" --output json
    if [ $? -ne 0 ]; then
        echo "Failed to create role definition."
        exit 1
    fi
    echo "Custom role $ROLE_NAME created."
    ROLE_ID=$(az role definition list --query "[?roleName=='$ROLE_NAME'].id" --output tsv)
else
    echo "Role $ROLE_NAME already exists."
fi

# Check if the Service Principal exists
echo "Checking if Service Principal $SP_NAME exists..."
sleep 60
SP_ID=$(az ad sp list --display-name "$SP_NAME" --query "[0].appId" --output tsv)
if [ -n "$SP_ID" ]; then
    echo "Service Principal $SP_NAME already exists. Skipping creation."
    SP_APP_ID="$SP_ID"
    SP_TENANT_ID=$(az ad sp show --id "$SP_APP_ID" --query "appOwnerOrganizationId" --output tsv)
else
    # Create the Service Principal
    echo "Creating Service Principal..."
    #SP_OUTPUT=$(az ad sp create-for-rbac --name "$SP_NAME" --role "$ROLE_NAME" --scope "/subscriptions/$SUBSCRIPTION_ID" --output json)
    SP_OUTPUT=$(az ad sp create-for-rbac --name "$SP_NAME" --output json)
    if [ $? -ne 0 ]; then
        echo "Failed to create Service Principal."
        exit 1
    fi

    SP_APP_ID=$(echo "$SP_OUTPUT" | jq -r '.appId')
    SP_TENANT_ID=$(echo "$SP_OUTPUT" | jq -r '.tenant')
fi

# Check if role assignment exists
echo "Checking if role assignment exists..."
ROLE_ASSIGNMENT_EXISTS=$(az role assignment list --assignee "$SP_APP_ID" --scope "/subscriptions/$SUBSCRIPTION_ID" --query "[?roleDefinitionName=='$ROLE_NAME'].id" --output tsv)

if [ -z "$ROLE_ASSIGNMENT_EXISTS" ]; then
    echo "Assigning role $ROLE_NAME to Service Principal..."
    az role assignment create --assignee "$SP_APP_ID" --role "$ROLE_ID" --scope "/subscriptions/$SUBSCRIPTION_ID"
    if [ $? -ne 0 ]; then
        echo "Failed to assign role."
        exit 1
    fi
    echo "Role $ROLE_NAME assigned to Service Principal."
else
    echo "Role $ROLE_NAME is already assigned to the Service Principal."
fi

echo "Checking if the Service Principal $SP_APP_ID has existing credentials..."
EXISTING_CREDENTIALS=$(az ad sp credential list --id "$SP_APP_ID" --output json)

if [ "$(echo "$EXISTING_CREDENTIALS" | jq '. | length')" -eq 0 ]; then
    echo "No existing credentials found. Resetting credentials for Service Principal $SP_APP_ID with an expiration of $EXPIRATION_YEARS years..."
    SP_CREDENTIALS_OUTPUT=$(az ad sp credential reset --id "$SP_APP_ID" --years "$EXPIRATION_YEARS")

    if [ $? -ne 0 ]; then
        echo "Failed to reset Service Principal credentials."
        exit 1
    fi

    SP_CLIENT_SECRET=$(echo "$SP_CREDENTIALS_OUTPUT" | jq -r '.password')

    echo "New credentials have been generated."
else
    echo "Existing credentials found. Skipping credential reset."
    SP_CLIENT_SECRET=$(echo "$EXISTING_CREDENTIALS" | jq -r '.[0].secretText')
fi

# Output credentials
echo ""
echo "Service Principal credentials:"
echo "Client ID: $SP_APP_ID"
echo "Client Secret: $SP_CLIENT_SECRET"
echo "Tenant ID: $SP_TENANT_ID"
echo ""
echo "Please save these credentials securely."

echo "Script execution completed successfully!"
