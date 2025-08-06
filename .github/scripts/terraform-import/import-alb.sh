#!/bin/bash
ALB_NAME=$1
AWS_REGION=$2
TERRAFORM_DIR=$3

echo "Attempting to import ALB: $ALB_NAME"
cd "$TERRAFORM_DIR"

ALB_ARN=$(aws elbv2 describe-load-balancers \
  --names "$ALB_NAME" \
  --region "$AWS_REGION" \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text 2>/dev/null || echo "None")

if [ "$ALB_ARN" != "None" ] && [ "$ALB_ARN" != "null" ]; then
  terraform import aws_lb.app_alb "$ALB_ARN" || true
fi
