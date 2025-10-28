#!/bin/bash

# Deploy Logic App Standard with Managed Identity
# This script deploys an Azure Logic App (Standard) using Bicep template

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Default values
RESOURCE_GROUP="ai-demos"
LOGIC_APP_NAME="mcplogicappdemocbx"
LOCATION="australiaeast"
SKU="WorkflowStandard"
SKU_CODE="WS1"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -g|--resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        -n|--name)
            LOGIC_APP_NAME="$2"
            shift 2
            ;;
        -l|--location)
            LOCATION="$2"
            shift 2
            ;;
        --sku)
            SKU="$2"
            shift 2
            ;;
        --sku-code)
            SKU_CODE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 -g <resource-group> -n <logic-app-name> [options]"
            echo ""
            echo "Required arguments:"
            echo "  -g, --resource-group    Resource group name"
            echo "  -n, --name              Logic App name"
            echo ""
            echo "Optional arguments:"
            echo "  -l, --location          Azure region (default: australiaeast)"
            echo "  --sku                   SKU tier (default: WorkflowStandard)"
            echo "  --sku-code              SKU code (default: WS1)"
            echo "  -h, --help              Show this help message"
            echo ""
            echo "Example:"
            echo "  $0 -g my-rg -n my-logic-app -l eastus"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$RESOURCE_GROUP" ]; then
    print_error "Resource group name is required. Use -g or --resource-group"
    exit 1
fi

if [ -z "$LOGIC_APP_NAME" ]; then
    print_error "Logic App name is required. Use -n or --name"
    exit 1
fi

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    print_error "Azure CLI is not installed. Please install it from https://aka.ms/azure-cli"
    exit 1
fi

# Check if logged in to Azure
print_info "Checking Azure login status..."
if ! az account show &> /dev/null; then
    print_error "Not logged in to Azure. Please run 'az login' first"
    exit 1
fi

# Get current subscription
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
print_info "Using subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"

# Create resource group if it doesn't exist
print_info "Checking if resource group '$RESOURCE_GROUP' exists..."
if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
    print_warning "Resource group '$RESOURCE_GROUP' does not exist. Creating..."
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
    print_info "Resource group created successfully"
else
    print_info "Resource group '$RESOURCE_GROUP' already exists"
fi

# Deploy the Bicep template
print_info "Starting deployment..."
print_info "  Logic App Name: $LOGIC_APP_NAME"
print_info "  Location: $LOCATION"
print_info "  SKU: $SKU ($SKU_CODE)"

DEPLOYMENT_NAME="logic-app-deployment-$(date +%Y%m%d-%H%M%S)"

az deployment group create \
    --name "$DEPLOYMENT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --template-file logic-app.bicep \
    --parameters \
        name="$LOGIC_APP_NAME" \
        location="$LOCATION" \
        sku="$SKU" \
        skuCode="$SKU_CODE" \
    --verbose

if [ $? -eq 0 ]; then
    print_info "Deployment completed successfully!"
    echo ""
    print_info "Resources created:"
    print_info "  - Logic App: $LOGIC_APP_NAME"
    print_info "  - Storage Account: $(az deployment group show -g "$RESOURCE_GROUP" -n "$DEPLOYMENT_NAME" --query properties.outputs.storageAccountName.value -o tsv 2>/dev/null || echo 'Check portal')"
    print_info "  - Managed Identity: id-$LOGIC_APP_NAME"
    print_info "  - App Service Plan: plan-$LOGIC_APP_NAME"
    echo ""
    print_info "You can access the Logic App at:"
    print_info "https://portal.azure.com/#resource/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Web/sites/$LOGIC_APP_NAME"
else
    print_error "Deployment failed. Check the error messages above."
    exit 1
fi
