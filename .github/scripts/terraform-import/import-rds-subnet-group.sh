#!/bin/bash
set -e

SG_NAME="$1"

if aws rds describe-db-subnet-groups --db-subnet-group-name "$SG_NAME" >/dev/null 2>&1; then
  echo "✅ RDS Subnet Group exists. Importing into Terraform..."
  terraform import aws_db_subnet_group.main "$SG_NAME" || echo "⚠️ Already imported."
else
  echo "ℹ️ RDS Subnet Group does not exist. Terraform will create it."
fi
