#!/bin/bash
set -e

ECR_NAME="$1"
AWS_REGION="$2"

echo "🔍 Checking if ECR repository '$ECR_NAME' exists in region '$AWS_REGION'..."

if aws ecr describe-repositories --repository-names "$ECR_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
  echo "✅ ECR repository '$ECR_NAME' exists."
  if ! terraform state list | grep -q "aws_ecr_repository.app_repo"; then
    echo "📥 Importing ECR repository into Terraform state..."
    terraform import aws_ecr_repository.app_repo "$ECR_NAME"
  else
    echo "⚠️ ECR repository already in Terraform state. Skipping import."
  fi
else
  echo "ℹ️ ECR repository '$ECR_NAME' does not exist. Terraform will create it."
fi
