#!/bin/bash
set -e

TG_NAME="$1"
AWS_REGION="$2"

echo "🔍 Checking if Target Group '$TG_NAME' exists in region '$AWS_REGION'..."

TG_ARN=$(aws elbv2 describe-target-groups --names "$TG_NAME" --region "$AWS_REGION" --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || true)

if [[ "$TG_ARN" != "None" && -n "$TG_ARN" ]]; then
  echo "✅ Target Group '$TG_NAME' exists."
  if ! terraform state list | grep -q "aws_lb_target_group.app_tg"; then
    echo "📥 Importing Target Group into Terraform state..."
    terraform import aws_lb_target_group.app_tg "$TG_ARN"
  else
    echo "⚠️ Target Group already in Terraform state. Skipping import."
  fi
else
  echo "ℹ️ Target Group '$TG_NAME' does not exist. Terraform will create it."
fi
