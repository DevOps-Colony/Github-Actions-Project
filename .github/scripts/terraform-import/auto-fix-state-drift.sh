#!/bin/bash

set -e

ENVIRONMENT="$1"
AWS_REGION="$2"
TF_DIR="$3"

echo "🔧 Auto-fixing state drift for environment: $ENVIRONMENT"

cd "$TF_DIR"

# Function to safely remove from state
safe_state_rm() {
    local resource="$1"
    echo "🗑️  Attempting to remove $resource from state..."
    if terraform state rm "$resource" 2>/dev/null; then
        echo "✅ Successfully removed $resource from state"
    else
        echo "⚠️  Resource $resource not in state or already removed"
    fi
}

# Function to check if resource exists in AWS
resource_exists() {
    local check_command="$1"
    if eval "$check_command" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Get current AWS account and VPC information
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "📍 AWS Account ID: $ACCOUNT_ID"

# Try to find existing VPC to understand the current state
EXISTING_VPC_ID=""
if resource_exists "aws ec2 describe-security-groups --region $AWS_REGION --filters 'Name=group-name,Values=bankapp-${ENVIRONMENT}-alb-*' --query 'SecurityGroups[0].GroupId'"; then
    EXISTING_VPC_ID=$(aws ec2 describe-security-groups --region $AWS_REGION --filters "Name=group-name,Values=bankapp-${ENVIRONMENT}-alb-*" --query 'SecurityGroups[0].VpcId' --output text)
    echo "📍 Found existing VPC ID from ALB security group: $EXISTING_VPC_ID"
elif resource_exists "aws eks describe-cluster --region $AWS_REGION --name bankapp-${ENVIRONMENT}"; then
    EXISTING_VPC_ID=$(aws eks describe-cluster --region $AWS_REGION --name "bankapp-${ENVIRONMENT}" --query 'cluster.resourcesVpcConfig.vpcId' --output text)
    echo "📍 Found existing VPC ID from EKS cluster: $EXISTING_VPC_ID"
fi

# If we have an existing VPC, get its subnets
if [ -n "$EXISTING_VPC_ID" ] && [ "$EXISTING_VPC_ID" != "null" ]; then
    EXISTING_PRIVATE_SUBNETS=$(aws ec2 describe-subnets --region "$AWS_REGION" --filters "Name=vpc-id,Values=$EXISTING_VPC_ID" "Name=tag:kubernetes.io/role/internal-elb,Values=1" --query 'Subnets[*].SubnetId' --output text)
    EXISTING_PUBLIC_SUBNETS=$(aws ec2 describe-subnets --region "$AWS_REGION" --filters "Name=vpc-id,Values=$EXISTING_VPC_ID" "Name=tag:kubernetes.io/role/elb,Values=1" --query 'Subnets[*].SubnetId' --output text)
    
    echo "📍 Existing private subnets: $EXISTING_PRIVATE_SUBNETS"
    echo "📍 Existing public subnets: $EXISTING_PUBLIC_SUBNETS"
fi

# List of resources that commonly cause state drift issues
DRIFT_PRONE_RESOURCES=(
    "aws_lb.app_alb"
    "aws_security_group.alb_sg"
    "aws_lb_target_group.app_tg"
    "aws_lb_listener.app_listener"
    "module.rds.aws_db_subnet_group.main"
    "module.rds.aws_security_group.rds_sg"
    "aws_db_instance.app_db"
    "module.rds.aws_db_instance.main"
)

echo "🔍 Checking for state drift in common problematic resources..."

# Remove resources with potential state drift
for resource in "${DRIFT_PRONE_RESOURCES[@]}"; do
    # Check if resource exists in state
    if terraform state show "$resource" >/dev/null 2>&1; then
        echo "🔍 Checking state drift for $resource"
        
        # Try a targeted plan to see if there are conflicts
        if ! terraform plan -target="$resource" >/dev/null 2>&1; then
            echo "⚠️  State drift detected in $resource"
            safe_state_rm "$resource"
        else
            echo "✅ $resource state is clean"
        fi
    fi
done

# Special handling for RDS subnet group VPC mismatch
if resource_exists "aws rds describe-db-subnet-groups --region $AWS_REGION --db-subnet-group-name bankapp-${ENVIRONMENT}-db-subnet-group"; then
    RDS_SUBNET_GROUP_VPC=$(aws rds describe-db-subnet-groups --region "$AWS_REGION" --db-subnet-group-name "bankapp-${ENVIRONMENT}-db-subnet-group" --query 'DBSubnetGroups[0].VpcId' --output text)
    
    if [ -n "$EXISTING_VPC_ID" ] && [ "$RDS_SUBNET_GROUP_VPC" != "$EXISTING_VPC_ID" ]; then
        echo "⚠️  RDS subnet group VPC mismatch detected!"
        echo "    RDS Subnet Group VPC: $RDS_SUBNET_GROUP_VPC"
        echo "    Expected VPC: $EXISTING_VPC_ID"
        
        # Remove RDS subnet group from state to force recreation
        safe_state_rm "module.rds.aws_db_subnet_group.main"
        
        # Also remove RDS instance that depends on it
        safe_state_rm "module.rds.aws_db_instance.main"
        safe_state_rm "aws_db_instance.app_db"
    fi
fi

# Special handling for ALB security group issues
if resource_exists "aws elbv2 describe-load-balancers --region $AWS_REGION --names bankapp-${ENVIRONMENT}-alb"; then
    ALB_SECURITY_GROUPS=$(aws elbv2 describe-load-balancers --region "$AWS_REGION" --names "bankapp-${ENVIRONMENT}-alb" --query 'LoadBalancers[0].SecurityGroups' --output text)
    
    echo "📍 Current ALB security groups: $ALB_SECURITY_GROUPS"
    
    # Check if the security groups exist and are in the right VPC
    for sg_id in $ALB_SECURITY_GROUPS; do
        if ! aws ec2 describe-security-groups --region "$AWS_REGION" --group-ids "$sg_id" >/dev/null 2>&1; then
            echo "⚠️  Security group $sg_id doesn't exist, removing ALB from state"
            safe_state_rm "aws_lb.app_alb"
            safe_state_rm "aws_security_group.alb_sg"
            break
        fi
    done
fi

# Clean up any lock files that might be causing issues
if [ -f ".terraform.tfstate.lock.info" ]; then
    echo "🗑️  Removing terraform lock file"
    rm -f ".terraform.tfstate.lock.info"
fi

# Force unlock if there's a stuck lock
echo "🔓 Force unlocking terraform state (if locked)"
terraform force-unlock -force $(terraform output -json 2>/dev/null | jq -r '.lock_id.value // empty') 2>/dev/null || true

echo "✅ State drift fix completed"

# Validate terraform configuration
echo "🔍 Validating terraform configuration..."
terraform validate

echo "🎯 Auto state drift fix process completed successfully"