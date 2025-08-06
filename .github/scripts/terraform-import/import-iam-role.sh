#!/bin/bash
set -e

IAM_ROLE_NAME="$1"
TF_RESOURCE="$2"
WORKDIR="$3"

echo "🔍 Checking if IAM Role '$IAM_ROLE_NAME' exists..."
if aws iam get-role --role-name "$IAM_ROLE_NAME" >/dev/null 2>&1; then
  echo "✅ IAM Role '$IAM_ROLE_NAME' exists."
  cd "$WORKDIR"

  if terraform state list 2>/dev/null | grep -q "$TF_RESOURCE"; then
    echo "ℹ️ IAM Role already in Terraform state. Skipping import."
  else
    echo "📥 Importing IAM Role into Terraform state..."
    terraform import "$TF_RESOURCE" "$IAM_ROLE_NAME" || echo "⚠️ Import failed, continuing..."
  fi
else
  echo "⚠️ IAM Role '$IAM_ROLE_NAME' does not exist. Terraform will create it."
fi
