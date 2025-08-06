#!/bin/bash
set -e

ECR_NAME="$1"
AWS_REGION="$2"
WORKDIR="$3"

echo "🔍 Checking if ECR repository '$ECR_NAME' exists in $AWS_REGION..."
if aws ecr describe-repositories --repository-names "$ECR_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
  echo "✅ ECR repository '$ECR_NAME' exists."
  cd "$WORKDIR"

  if terraform state list 2>/dev/null | grep -q "aws_ecr_repository.app_repo"; then
    echo "ℹ️ ECR repository already in Terraform state. Skipping import."
  else
    echo "📥 Importing ECR repository into Terraform state..."
    terraform import aws_ecr_repository.app_repo "$ECR_NAME" || echo "⚠️ Import failed, continuing..."
  fi
else
  echo "⚠️ ECR repository '$ECR_NAME' does not exist. Terraform will create it."
fi
