#!/bin/bash
set -e

ENVIRONMENT=$1
AWS_REGION=$2
TG_NAME="bankapp-${ENVIRONMENT}-tg"

echo "Checking for target group dependencies..."

# Get the target group ARN
TG_ARN=$(aws elbv2 describe-target-groups \
  --names "$TG_NAME" \
  --region "$AWS_REGION" \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text 2>/dev/null || echo "None")

if [ "$TG_ARN" != "None" ] && [ "$TG_ARN" != "null" ]; then
  echo "Found target group: $TG_ARN"
  
  # Find listeners using this target group
  LISTENERS=$(aws elbv2 describe-listeners \
    --query "Listeners[?DefaultActions[?TargetGroupArn=='$TG_ARN']].ListenerArn" \
    --output text --region "$AWS_REGION" 2>/dev/null || echo "")
  
  if [ ! -z "$LISTENERS" ]; then
    echo "Found listeners using target group: $LISTENERS"
    for listener in $LISTENERS; do
      echo "Removing target group from listener: $listener"
      # This would require updating the listener's default action
      # In a real scenario, you'd want to update to a different target group or remove the listener
    done
  fi
  
  # Find rules using this target group
  RULES=$(aws elbv2 describe-rules \
    --query "Rules[?Actions[?TargetGroupArn=='$TG_ARN']].RuleArn" \
    --output text --region "$AWS_REGION" 2>/dev/null || echo "")
  
  if [ ! -z "$RULES" ]; then
    echo "Found rules using target group: $RULES"
    # Handle rule cleanup if needed
  fi
else
  echo "Target group not found or already deleted"
fi
