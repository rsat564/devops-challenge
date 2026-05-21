#!/usr/bin/env bash
#--------------------------------------------------------------
# Terraform Remote State Backend Setup Script
#
# This script creates the Azure Storage Account used to store
# Terraform state files. Run this ONCE before any Terraform
# deployment.
#
# Prerequisites:
#   - Azure CLI installed and authenticated (az login)
#   - Subscription set (az account set --subscription <id>)
#
# Usage:
#   chmod +x scripts/setup-backend.sh
#   ./scripts/setup-backend.sh
#
# For different projects/orgs, modify the variables below.
#--------------------------------------------------------------

set -euo pipefail

#--------------------------------------------------------------
# Configuration (modify for your organization)
#--------------------------------------------------------------
RESOURCE_GROUP_NAME="rg-cloudops-tfstate"
STORAGE_ACCOUNT_NAME="srcloudopstfstate"
CONTAINER_NAME="tfstate"
LOCATION="eastus"
SKU="Standard_ZRS"  # Zone-redundant for HA

# Tags
TAG_PROJECT="cloudops"
TAG_MANAGEDBY="script"
TAG_PURPOSE="terraform-state"

#--------------------------------------------------------------
# Colors for output
#--------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}============================================${NC}"
echo -e "${YELLOW} Terraform State Backend Setup${NC}"
echo -e "${YELLOW}============================================${NC}"
echo ""

#--------------------------------------------------------------
# Validate Azure CLI is authenticated
#--------------------------------------------------------------
echo -e "${GREEN}[1/6]${NC} Validating Azure CLI authentication..."
if ! az account show > /dev/null 2>&1; then
    echo -e "${RED}ERROR: Not logged in to Azure CLI. Run 'az login' first.${NC}"
    exit 1
fi

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
echo "  Subscription: ${SUBSCRIPTION_NAME} (${SUBSCRIPTION_ID})"
echo ""

#--------------------------------------------------------------
# Check & Create Resource Group
#--------------------------------------------------------------
echo -e "${GREEN}[2/6]${NC} Checking Resource Group: ${RESOURCE_GROUP_NAME}..."
if [ "$(az group exists --name "${RESOURCE_GROUP_NAME}")" = "false" ]; then
    az group create \
        --name "${RESOURCE_GROUP_NAME}" \
        --location "${LOCATION}" \
        --tags project="${TAG_PROJECT}" managedby="${TAG_MANAGEDBY}" purpose="${TAG_PURPOSE}" \
        --output none
    echo "  Resource Group created in ${LOCATION}"
else
    echo "  Resource Group already exists. Skipping creation."
fi
echo ""

#--------------------------------------------------------------
# Check & Create Storage Account
#--------------------------------------------------------------
echo -e "${GREEN}[3/6]${NC} Checking Storage Account: ${STORAGE_ACCOUNT_NAME}..."
if ! az storage account show --name "${STORAGE_ACCOUNT_NAME}" --resource-group "${RESOURCE_GROUP_NAME}" &>/dev/null; then
    az storage account create \
        --name "${STORAGE_ACCOUNT_NAME}" \
        --resource-group "${RESOURCE_GROUP_NAME}" \
        --location "${LOCATION}" \
        --sku "${SKU}" \
        --kind "StorageV2" \
        --min-tls-version "TLS1_2" \
        --allow-blob-public-access false \
        --https-only true \
        --tags project="${TAG_PROJECT}" managedby="${TAG_MANAGEDBY}" purpose="${TAG_PURPOSE}" \
        --output none
    echo "  Storage Account created with ${SKU} redundancy"
else
    echo "  Storage Account already exists. Skipping creation."
fi
echo ""

#--------------------------------------------------------------
# Enable Versioning (idempotent operation)
#--------------------------------------------------------------
echo -e "${GREEN}[4/6]${NC} Ensuring blob versioning is enabled..."
az storage account blob-service-properties update \
    --account-name "${STORAGE_ACCOUNT_NAME}" \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --enable-versioning true \
    --enable-delete-retention true \
    --delete-retention-days 30 \
    --output none

echo "  Versioning configuration applied (soft-delete retention: 30 days)"
echo ""

#--------------------------------------------------------------
# Check & Create State Container
#--------------------------------------------------------------
echo -e "${GREEN}[5/6]${NC} Checking blob container: ${CONTAINER_NAME}..."
CONTAINER_EXISTS=$(az storage container exists \
    --name "${CONTAINER_NAME}" \
    --account-name "${STORAGE_ACCOUNT_NAME}" \
    --auth-mode login \
    --query exists \
    --output tsv)

if [ "$CONTAINER_EXISTS" = "false" ]; then
    az storage container create \
        --name "${CONTAINER_NAME}" \
        --account-name "${STORAGE_ACCOUNT_NAME}" \
        --auth-mode login \
        --output none
    echo "  Container '${CONTAINER_NAME}' created"
else
    echo "  Container '${CONTAINER_NAME}' already exists. Skipping creation."
fi
echo ""


#--------------------------------------------------------------
# Summary
#--------------------------------------------------------------
echo -e "${YELLOW}============================================${NC}"
echo -e "${GREEN} Setup Complete!${NC}"
echo -e "${YELLOW}============================================${NC}"
echo ""
echo "Backend configuration for Terraform:"
echo ""
echo "  resource_group_name  = \"${RESOURCE_GROUP_NAME}\""
echo "  storage_account_name = \"${STORAGE_ACCOUNT_NAME}\""
echo "  container_name       = \"${CONTAINER_NAME}\""
echo "  key                  = \"<env>/terraform.tfstate\""
echo ""
echo "Initialize Terraform with:"
echo ""
echo "  cd infrastructure"
echo "  terraform init -backend-config=environments/dev-eastus.backend.hcl"
echo ""
echo -e "${YELLOW}NOTE: For large teams, see docs/STATE-MANAGEMENT.md${NC}"
echo -e "${YELLOW}for state locking, RBAC, and multi-team best practices.${NC}"