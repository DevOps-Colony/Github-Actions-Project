#!/bin/bash
set -e

LOCK_TABLE="$1"
REGION="$2"

echo "🔍 Checking for stale Terraform locks in DynamoDB table: $LOCK_TABLE..."

# Scan the DynamoDB table for any locks
ITEMS=$(aws dynamodb scan \
  --table-name "$LOCK_TABLE" \
  --region "$REGION" \
  --query "Items" \
  --output json 2>/dev/null || echo "[]")

# If no items are found, skip unlocking
if [ "$ITEMS" == "[]" ] || [ -z "$ITEMS" ]; then
  echo "✅ No locks found. Skipping force unlock."
  exit 0
fi

# Safely extract lock UUID
LOCK_UUID=$(echo "$ITEMS" | jq -r '.[0].Info.S | fromjson | .ID // empty')

# If lock UUID is missing or invalid, skip
if [ -z "$LOCK_UUID" ]; then
  echo "⚠ No valid lock UUID found in table. Skipping force unlock."
  exit 0
fi

# Force unlock in Terraform
echo "🔓 Found lock UUID: $LOCK_UUID — forcing unlock..."
terraform force-unlock -force "$LOCK_UUID" || true
