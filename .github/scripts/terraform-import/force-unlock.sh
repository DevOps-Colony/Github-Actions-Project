#!/bin/bash
set -e

LOCK_TABLE="$1"
REGION="$2"

echo "🔍 Checking for stale Terraform locks in DynamoDB table: $LOCK_TABLE..."

# Scan the table
ITEMS=$(aws dynamodb scan \
  --table-name "$LOCK_TABLE" \
  --region "$REGION" \
  --query "Items" \
  --output json 2>/dev/null || echo "[]")

# Exit if table is empty or no lock items
if [ "$ITEMS" == "[]" ] || [ -z "$ITEMS" ]; then
  echo "✅ No locks found. Skipping force unlock."
  exit 0
fi

# Safely extract the UUID if present
LOCK_UUID=$(echo "$ITEMS" | jq -r '.[0].Info.S | try (fromjson | .ID) catch empty')

if [ -z "$LOCK_UUID" ]; then
  echo "⚠ No valid lock UUID found in table. Skipping force unlock."
  exit 0
fi

# Force unlock
echo "🔓 Found lock UUID: $LOCK_UUID — forcing unlock..."
terraform force-unlock -force "$LOCK_UUID" || true
