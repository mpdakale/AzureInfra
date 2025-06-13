#!/bin/bash

# Script for creating Azure resources: Resource Group, Storage Account, and Container
# Usage: ./tf-backend.sh [region]

# Define default region if not provided
DEFAULT_REGION="eastus"
# Define static project name
PROJECT_NAME="netappcdmt"
# environment
ENVIRONMENT="tf"

# Function to display help
function display_help {
  echo "Usage: $0 [region]"
  echo ""
  echo "Parameters:"
  echo "  [region]         The Azure region where resources will be created. If not provided, 'eastus' will be used as the default region."
  echo ""
  echo "Examples:"
  echo "  $0"
  echo "  $0 westus"
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
if [ "$#" -gt 1 ]; then
  echo "Error: Too many arguments provided."
  display_help
fi

REGION=${1:-$DEFAULT_REGION}  # Use default region if not provided

# Define resource names
RESOURCE_GROUP="${PROJECT_NAME}-${ENVIRONMENT}-rg"
STORAGE_ACCOUNT="${PROJECT_NAME}${ENVIRONMENT}stac"
CONTAINER_NAME="${PROJECT_NAME}-${ENVIRONMENT}"

echo ""
echo "Creating resources in region: $REGION"
echo ""
echo "Resource Group: $RESOURCE_GROUP"
echo "Storage Account: $STORAGE_ACCOUNT"
echo "Container Name: $CONTAINER_NAME"
echo ""

# Create resource group if it doesn't exist
echo "Checking if resource group $RESOURCE_GROUP exists..."
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

# Check if the storage account exists
echo "Checking if storage account $STORAGE_ACCOUNT exists..."
if ! az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" > /dev/null 2>&1; then
  echo "Storage account $STORAGE_ACCOUNT does not exist. Creating..."
  az storage account create --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" --location "$REGION" --sku Standard_LRS --output table
  if [ $? -ne 0 ]; then
    echo "Failed to create storage account $STORAGE_ACCOUNT."
    exit 1
  fi
else
  echo "Storage account $STORAGE_ACCOUNT already exists."
fi

# Retrieve storage account key
echo "Retrieving storage account key..."
STORAGE_KEY=$(az storage account keys list --resource-group "$RESOURCE_GROUP" --account-name "$STORAGE_ACCOUNT" --query '[0].value' --output tsv)
if [ $? -ne 0 ]; then
  echo "Failed to retrieve storage account key for $STORAGE_ACCOUNT."
  exit 1
fi

# Create container if it doesn't exist
echo "Checking if container $CONTAINER_NAME exists..."
if ! az storage container show --name "$CONTAINER_NAME" --account-name "$STORAGE_ACCOUNT" --account-key "$STORAGE_KEY" > /dev/null 2>&1; then
  echo "Container $CONTAINER_NAME does not exist. Creating..."
  az storage container create --name "$CONTAINER_NAME" --account-name "$STORAGE_ACCOUNT" --account-key "$STORAGE_KEY" --output table
  if [ $? -ne 0 ]; then
    echo "Failed to create container $CONTAINER_NAME."
    exit 1
  fi
else
  echo "Container $CONTAINER_NAME already exists."
fi

echo ""
echo "Resource creation completed successfully!"
echo "Resource Group: $RESOURCE_GROUP"
echo "Storage Account: $STORAGE_ACCOUNT"
echo "Container Name: $CONTAINER_NAME"
echo ""
echo "Storage Account Key: $STORAGE_KEY"
echo ""
