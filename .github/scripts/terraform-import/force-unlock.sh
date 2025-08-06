#!/bin/bash
set -e

LOCK_TABLE="$1"
AWS_REGION="$2"

echo "🔍 Checking for stale Terraform locks in DynamoDB table: $LOCK_TABLE..."
ITEM=$(aws dynamodb scan \
  --table-name "$LOCK_TABLE" \
  --region "$AWS_REGION" \
  --query "Items" \
  --output json 2>/dev/null || echo "[]")

if [[ "$ITEM" != "[]" && "$ITEM" != "null" ]]; then
  LOCK_UUID=$(echo "$ITEM" | jq -r '.[0].Info.S | fromjson | .ID' 2>/dev/null || echo "")
  if [[ -n "$LOCK_UUID" && "$LOCK_UUID" != "null" ]]; then
    echo "🛠 Found lock UUID: $LOCK_UUID — forcing unlock..."
    terraform force-unlock -force "$LOCK_UUID" || true
  else
    echo "ℹ️ No valid lock UUID found."
  fi
else
  echo "✅ No lock found, continuing..."
fi
