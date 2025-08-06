#!/bin/bash
set -e

TG_NAME="$1"
AWS_REGION="$2"
WORKDIR="$3"

echo "🔍 Checking if Target Group '$TG_NAME' exists in $AWS_REGION..."
TG_ARN=$(aws elbv2 describe-target-groups --names "$TG_NAME" --region "$AWS_REGION" \
  --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null || echo "null")

if [[ "$TG_ARN" != "null" && -n "$TG_ARN" ]]; then
  echo "✅ Target Group '$TG_NAME' exists with ARN: $TG_ARN"
  cd "$WORKDIR"

  if terraform state list 2>/dev/null | grep -q "aws_lb_target_group.app_tg"; then
    echo "ℹ️ Target Group already in Terraform state. Skipping import."
  else
    echo "📥 Importing Target Group into Terraform state..."
    terraform import aws_lb_target_group.app_tg "$TG_ARN" || echo "⚠️ Import failed, continuing..."
  fi
else
  echo "⚠️ Target Group '$TG_NAME' does not exist. Terraform will create it."
fi
