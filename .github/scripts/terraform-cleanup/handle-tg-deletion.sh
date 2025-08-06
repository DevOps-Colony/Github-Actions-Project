#!/bin/bash
set -e

ENVIRONMENT=$1
AWS_REGION=$2
TG_NAME="bankapp-${ENVIRONMENT}-tg"

echo "🔍 Checking for target group dependencies..."

# Get the target group ARN
TG_ARN=$(aws elbv2 describe-target-groups \
  --names "$TG_NAME" \
  --region "$AWS_REGION" \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text 2>/dev/null || echo "None")

if [ "$TG_ARN" != "None" ] && [ "$TG_ARN" != "null" ] && [ "$TG_ARN" != "" ]; then
  echo "📍 Found target group: $TG_ARN"
  
  # Get all load balancers and find listeners using this target group
  LB_ARNS=$(aws elbv2 describe-load-balancers \
    --region "$AWS_REGION" \
    --query 'LoadBalancers[].LoadBalancerArn' \
    --output text 2>/dev/null || echo "")
  
  for LB_ARN in $LB_ARNS; do
    if [ ! -z "$LB_ARN" ] && [ "$LB_ARN" != "None" ]; then
      # Find listeners that use this target group in default action
      LISTENERS=$(aws elbv2 describe-listeners \
        --load-balancer-arn "$LB_ARN" \
        --region "$AWS_REGION" \
        --query "Listeners[?DefaultActions[?TargetGroupArn=='$TG_ARN']].ListenerArn" \
        --output text 2>/dev/null || echo "")
      
      if [ ! -z "$LISTENERS" ] && [ "$LISTENERS" != "None" ]; then
        echo "🗑️ Found listeners using target group: $LISTENERS"
        for listener in $LISTENERS; do
          echo "🗑️ Deleting listener: $listener"
          aws elbv2 delete-listener --listener-arn "$listener" --region "$AWS_REGION" || true
          sleep 5
        done
      fi
      
      # Check all listeners for rules that use this target group
      ALL_LISTENERS=$(aws elbv2 describe-listeners \
        --load-balancer-arn "$LB_ARN" \
        --region "$AWS_REGION" \
        --query 'Listeners[].ListenerArn' \
        --output text 2>/dev/null || echo "")
      
      for listener in $ALL_LISTENERS; do
        if [ ! -z "$listener" ] && [ "$listener" != "None" ]; then
          RULES=$(aws elbv2 describe-rules \
            --listener-arn "$listener" \
            --region "$AWS_REGION" \
            --query "Rules[?Actions[?TargetGroupArn=='$TG_ARN']].RuleArn" \
            --output text 2>/dev/null || echo "")
          
          if [ ! -z "$RULES" ] && [ "$RULES" != "None" ]; then
            echo "🗑️ Found rules using target group: $RULES"
            for rule in $RULES; do
              if [ "$rule" != "default" ]; then
                echo "🗑️ Deleting rule: $rule"
                aws elbv2 delete-rule --rule-arn "$rule" --region "$AWS_REGION" || true
                sleep 2
              fi
            done
          fi
        fi
      done
    fi
  done
  
  echo "⏳ Waiting 30 seconds for cleanup to propagate..."
  sleep 30
  
else
  echo "✅ Target group not found or already deleted"
fi
