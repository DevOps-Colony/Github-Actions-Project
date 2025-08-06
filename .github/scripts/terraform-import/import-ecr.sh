#!/bin/bash
set -e

ECR_NAME="$1"
AWS_REGION="$2"

echo "🔍 Checking if ECR repo '$ECR_NAME' exists in $AWS_REGION..."
if aws ecr describe-repositories --repository-names "$ECR_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
  echo "✅ ECR repo exists. Importing into Terraform..."
  terraform import aws_ecr_repository.app_repo "$ECR_NAME" || echo "⚠️ Already imported."
else
  echo "ℹ️ ECR repo does not exist. Terraform will create it."
fi
