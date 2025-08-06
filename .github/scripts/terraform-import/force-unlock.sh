#!/bin/bash
set -e

LOCK_TABLE_NAME="$1"
AWS_REGION="$2"

if aws dynamodb describe-table --table-name "$LOCK_TABLE_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
  ITEM=$(aws dynamodb scan \
    --table-name "$LOCK_TABLE_NAME" \
    --region "$AWS_REGION" \
    --query "Items" \
    --output json)

  if [ "$ITEM" != "[]" ]; then
    LOCK_UUID=$(echo "$ITEM" | jq -r '.[0].Info.S | fromjson | .ID')
    echo "🔓 Found lock UUID: $LOCK_UUID — forcing unlock..."
    terraform force-unlock -force "$LOCK_UUID" || true
  else
    echo "✅ No lock found."
  fi
else
  echo "ℹ️ Lock table does not exist yet. Skipping unlock check."
fi
