#!/bin/bash
set -e

SUBNET_GROUP_NAME="$1"
RESOURCE_ADDRESS="$2"
WORK_DIR="$3"

cd "$WORK_DIR"

if aws rds describe-db-subnet-groups \
    --db-subnet-group-name "$SUBNET_GROUP_NAME" \
    --region "$AWS_REGION" >/dev/null 2>&1; then
    
    echo "RDS Subnet Group '$SUBNET_GROUP_NAME' exists in AWS."
    
    if ! terraform state list | grep -q "$RESOURCE_ADDRESS"; then
        echo "Importing $RESOURCE_ADDRESS..."
        terraform import "$RESOURCE_ADDRESS" "$SUBNET_GROUP_NAME"
    else
        echo "$RESOURCE_ADDRESS already in Terraform state. Skipping import."
    fi
else
    echo "RDS Subnet Group '$SUBNET_GROUP_NAME' not found in AWS. Terraform will create it."
fi
