#!/bin/bash
set -e

ROLE_NAME="$1"
TF_RESOURCE="$2"

if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  echo "✅ IAM Role exists. Importing into Terraform..."
  terraform import "$TF_RESOURCE" "$ROLE_NAME" || echo "⚠️ Already imported."
else
  echo "ℹ️ IAM Role does not exist. Terraform will create it."
fi
