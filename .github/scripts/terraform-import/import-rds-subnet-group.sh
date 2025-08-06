#!/bin/bash
set -e

SUBNET_GROUP_NAME="$1"
RESOURCE_NAME="$2"

echo "🔍 Checking if RDS Subnet Group '$SUBNET_GROUP_NAME' exists..."

if aws rds describe-db-subnet-groups --db-subnet-group-name "$SUBNET_GROUP_NAME" >/dev/null 2>&1; then
  echo "✅ RDS Subnet Group '$SUBNET_GROUP_NAME' exists."
  if ! terraform state list | grep -q "$RESOURCE_NAME"; then
    echo "📥 Importing RDS Subnet Group into Terraform state..."
    terraform import "$RESOURCE_NAME" "$SUBNET_GROUP_NAME"
  else
    echo "⚠️ RDS Subnet Group already in Terraform state. Skipping import."
  fi
else
  echo "ℹ️ RDS Subnet Group '$SUBNET_GROUP_NAME' does not exist. Terraform will create it."
fi
