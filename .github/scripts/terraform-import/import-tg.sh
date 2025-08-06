#!/bin/bash
set -e

TG_NAME="$1"
AWS_REGION="$2"

TG_ARN=$(aws elbv2 describe-target-groups --names "$TG_NAME" --region "$AWS_REGION" --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null || echo "")
if [ -n "$TG_ARN" ] && [ "$TG_ARN" != "None" ]; then
  echo "✅ Target Group exists. Importing into Terraform..."
  terraform import aws_lb_target_group.app_tg "$TG_ARN" || echo "⚠️ Already imported."
else
  echo "ℹ️ Target Group does not exist. Terraform will create it."
fi
