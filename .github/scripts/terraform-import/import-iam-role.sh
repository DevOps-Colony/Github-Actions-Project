#!/bin/bash
set -e

IAM_ROLE_NAME="$1"
RESOURCE_NAME="$2"

echo "🔍 Checking if IAM Role '$IAM_ROLE_NAME' exists..."

if aws iam get-role --role-name "$IAM_ROLE_NAME" >/dev/null 2>&1; then
  echo "✅ IAM Role '$IAM_ROLE_NAME' exists."
  if ! terraform state list | grep -q "$RESOURCE_NAME"; then
    echo "📥 Importing IAM Role into Terraform state..."
    terraform import "$RESOURCE_NAME" "$IAM_ROLE_NAME"
  else
    echo "⚠️ IAM Role already in Terraform state. Skipping import."
  fi
else
  echo "ℹ️ IAM Role '$IAM_ROLE_NAME' does not exist. Terraform will create it."
fi
