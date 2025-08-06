#!/bin/bash
set -e

SUBNET_GROUP_NAME="$1"
TF_RESOURCE="$2"
WORKDIR="$3"

echo "🔍 Checking if RDS Subnet Group '$SUBNET_GROUP_NAME' exists..."
if aws rds describe-db-subnet-groups --db-subnet-group-name "$SUBNET_GROUP_NAME" >/dev/null 2>&1; then
  echo "✅ RDS Subnet Group '$SUBNET_GROUP_NAME' exists."
  cd "$WORKDIR"

  if terraform state list 2>/dev/null | grep -q "$TF_RESOURCE"; then
    echo "ℹ️ RDS Subnet Group already in Terraform state. Skipping import."
  else
    echo "📥 Importing RDS Subnet Group into Terraform state..."
    terraform import "$TF_RESOURCE" "$SUBNET_GROUP_NAME" || echo "⚠️ Import failed, continuing..."
  fi
else
  echo "⚠️ RDS Subnet Group '$SUBNET_GROUP_NAME' does not exist. Terraform will create it."
fi
