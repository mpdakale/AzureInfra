#!/bin/bash

# Script for creating Azure resources: Resource Group
# Usage: ./azure-initial-setup.sh <environment> [region]

# Define default region if not provided
DEFAULT_REGION="eastus"

# Define static project name
PROJECT_NAME="netappcdmt"

# Function to display help
function display_help {
  echo "Usage: $0 <environment> [region]"
  echo ""
  echo "Parameters:"
  echo "  <environment>    The environment name (e.g., dev, test, prod). This will be used in resource naming to differentiate environments."
  echo "  [region]         The Azure region where resources will be created. If not provided, 'eastus' will be used as the default region."
  echo ""
  echo "Examples:"
  echo "  $0 dev"
  echo "  $0 prod westus"
  echo ""
  exit 0
}

# Check if help is requested
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  display_help
fi

# Check if Azure CLI is logged in
# If not logged in, prompt the user to log in and exit the script
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

# Validate input parameters
if [ "$#" -lt 1 ]; then
  echo "Error: Insufficient arguments provided."
  display_help
fi

ENVIRONMENT=$1
REGION=${2:-$DEFAULT_REGION}  # Use default region if not provided

# Define resource names
RESOURCE_GROUP="${PROJECT_NAME}-${ENVIRONMENT}-rg"

echo ""
echo "Creating resources in region: $REGION"
echo ""
echo "Resource Group: $RESOURCE_GROUP"
echo ""

# Create resource group if it doesn't exist
echo "Checking if resource group $RESOURCE_GROUP exists..."
echo ""
if ! az group show --name "$RESOURCE_GROUP" > /dev/null 2>&1; then
  echo "Resource group $RESOURCE_GROUP does not exist. Creating..."
  az group create --name "$RESOURCE_GROUP" --location "$REGION" --output table
  if [ $? -ne 0 ]; then
    echo "Failed to create resource group $RESOURCE_GROUP."
    exit 1
  fi
else
  echo "Resource group $RESOURCE_GROUP already exists."
fi