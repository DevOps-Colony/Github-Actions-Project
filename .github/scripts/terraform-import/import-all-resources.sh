#!/bin/bash

set -e

ENVIRONMENT="$1"
AWS_REGION="$2"
TF_DIR="$3"

echo "📦 Comprehensive resource import for environment: $ENVIRONMENT"

cd "$TF_DIR"

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "📍 AWS Account ID: $ACCOUNT_ID"

# Function to safely import resource
safe_import() {
    local tf_resource="$1"
    local aws_resource_id="$2"
    local resource_type="$3"
    
    echo "🔍 Checking $resource_type: $aws_resource_id"
    
    if terraform state show "$tf_resource" >/dev/null 2>&1; then
        echo "⚠️  $tf_resource already exists in state, skipping"
        return 0
    fi
    
    echo "📦 Attempting to import $tf_resource with ID $aws_resource_id"
    
    if terraform import "$tf_resource" "$aws_resource_id" 2>/dev/null; then
        echo "✅ Successfully imported $tf_resource"
        return 0
    else
        echo "❌ Failed to import $tf_resource (resource might not exist)"
        return 1
    fi
}

# Function to check if resource exists in AWS
resource_exists_aws() {
    local check_command="$1"
    eval "$check_command" >/dev/null 2>&1
}

echo "🚀 Starting comprehensive resource import process..."

# 1. Import VPC and related networking resources
echo "🌐 Importing VPC and networking resources..."

VPC_ID=""
if resource_exists_aws "aws ec2 describe-vpcs --region $AWS_REGION --filters 'Name=tag:Name,Values=bankapp-${ENVIRONMENT}' --query 'Vpcs[0].VpcId'"; then
    VPC_ID=$(aws ec2 describe-vpcs --region $AWS_REGION --filters "Name=tag:Name,Values=bankapp-${ENVIRONMENT}" --query 'Vpcs[0].VpcId' --output text)
    safe_import "module.vpc.aws_vpc.main" "$VPC_ID" "VPC"
    
    # Import Internet Gateway
    if resource_exists_aws "aws ec2 describe-internet-gateways --region $AWS_REGION --filters 'Name=attachment.vpc-id,Values=$VPC_ID' --query 'InternetGateways[0].InternetGatewayId'"; then
        IGW_ID=$(aws ec2 describe-internet-gateways --region $AWS_REGION --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[0].InternetGatewayId' --output text)
        safe_import "module.vpc.aws_internet_gateway.main" "$IGW_ID" "Internet Gateway"
    fi
    
    # Import NAT Gateways
    NAT_GATEWAY_IDS=$(aws ec2 describe-nat-gateways --region $AWS_REGION --filter "Name=vpc-id,Values=$VPC_ID" --query 'NatGateways[].NatGatewayId' --output text)
    if [ -n "$NAT_GATEWAY_IDS" ] && [ "$NAT_GATEWAY_IDS" != "None" ]; then
        NAT_COUNT=0
        for nat_id in $NAT_GATEWAY_IDS; do
            safe_import "module.vpc.aws_nat_gateway.main[$NAT_COUNT]" "$nat_id" "NAT Gateway"
            NAT_COUNT=$((NAT_COUNT + 1))
        done
    fi
    
    # Import Subnets
    PRIVATE_SUBNET_IDS=$(aws ec2 describe-subnets --region $AWS_REGION --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=*private*" --query 'Subnets[].SubnetId' --output text)
    if [ -n "$PRIVATE_SUBNET_IDS" ] && [ "$PRIVATE_SUBNET_IDS" != "None" ]; then
        SUBNET_COUNT=0
        for subnet_id in $PRIVATE_SUBNET_IDS; do
            safe_import "module.vpc.aws_subnet.private[$SUBNET_COUNT]" "$subnet_id" "Private Subnet"
            SUBNET_COUNT=$((SUBNET_COUNT + 1))
        done
    fi
    
    PUBLIC_SUBNET_IDS=$(aws ec2 describe-subnets --region $AWS_REGION --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=*public*" --query 'Subnets[].SubnetId' --output text)
    if [ -n "$PUBLIC_SUBNET_IDS" ] && [ "$PUBLIC_SUBNET_IDS" != "None" ]; then
        SUBNET_COUNT=0
        for subnet_id in $PUBLIC_SUBNET_IDS; do
            safe_import "module.vpc.aws_subnet.public[$SUBNET_COUNT]" "$subnet_id" "Public Subnet"
            SUBNET_COUNT=$((SUBNET_COUNT + 1))
        done
    fi
    
    # Import Route Tables
    PRIVATE_RT_IDS=$(aws ec2 describe-route-tables --region $AWS_REGION --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=*private*" --query 'RouteTables[].RouteTableId' --output text)
    if [ -n "$PRIVATE_RT_IDS" ] && [ "$PRIVATE_RT_IDS" != "None" ]; then
        RT_COUNT=0
        for rt_id in $PRIVATE_RT_IDS; do
            safe_import "module.vpc.aws_route_table.private[$RT_COUNT]" "$rt_id" "Private Route Table"
            RT_COUNT=$((RT_COUNT + 1))
        done
    fi
    
    if resource_exists_aws "aws ec2 describe-route-tables --region $AWS_REGION --filters 'Name=vpc-id,Values=$VPC_ID' 'Name=tag:Name,Values=*public*' --query 'RouteTables[0].RouteTableId'"; then
        PUBLIC_RT_ID=$(aws ec2 describe-route-tables --region $AWS_REGION --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=*public*" --query 'RouteTables[0].RouteTableId' --output text)
        safe_import "module.vpc.aws_route_table.public" "$PUBLIC_RT_ID" "Public Route Table"
    fi
fi

# 2. Import EKS Cluster and related resources
echo "☸️  Importing EKS cluster and related resources..."

if resource_exists_aws "aws eks describe-cluster --region $AWS_REGION --name bankapp-${ENVIRONMENT}"; then
    safe_import "module.eks.aws_eks_cluster.main" "bankapp-${ENVIRONMENT}" "EKS Cluster"
    
    # Import EKS Node Group
    if resource_exists_aws "aws eks describe-nodegroup --region $AWS_REGION --cluster-name bankapp-${ENVIRONMENT} --nodegroup-name main"; then
        safe_import "module.eks.aws_eks_node_group.main[\"main\"]" "bankapp-${ENVIRONMENT}:main" "EKS Node Group"
    fi
    
    # Import EKS Cluster IAM Role
    EKS_ROLE_NAME=$(aws eks describe-cluster --region $AWS_REGION --name "bankapp-${ENVIRONMENT}" --query 'cluster.roleArn' --output text | awk -F'/' '{print $NF}')
    if [ -n "$EKS_ROLE_NAME" ] && [ "$EKS_ROLE_NAME" != "null" ]; then
        safe_import "module.eks.aws_iam_role.cluster" "$EKS_ROLE_NAME" "EKS Cluster IAM Role"
    fi
    
    # Import Node Group IAM Role
    NODE_ROLE_ARN=$(aws eks describe-nodegroup --region $AWS_REGION --cluster-name "bankapp-${ENVIRONMENT}" --nodegroup-name main --query 'nodegroup.nodeRole' --output text 2>/dev/null || echo "")
    if [ -n "$NODE_ROLE_ARN" ] && [ "$NODE_ROLE_ARN" != "null" ]; then
        NODE_ROLE_NAME=$(echo "$NODE_ROLE_ARN" | awk -F'/' '{print $NF}')
        safe_import "module.eks.aws_iam_role.node" "$NODE_ROLE_NAME" "EKS Node Group IAM Role"
    fi
    
    # Import OIDC Provider
    OIDC_ISSUER=$(aws eks describe-cluster --region $AWS_REGION --name "bankapp-${ENVIRONMENT}" --query 'cluster.identity.oidc.issuer' --output text)
    if [ -n "$OIDC_ISSUER" ] && [ "$OIDC_ISSUER" != "null" ]; then
        OIDC_PROVIDER_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_ISSUER#https://}"
        if resource_exists_aws "aws iam get-open-id-connect-provider --open-id-connect-provider-arn $OIDC_PROVIDER_ARN"; then
            safe_import "module.eks.aws_iam_openid_connect_provider.oidc_provider" "$OIDC_PROVIDER_ARN" "EKS OIDC Provider"
        fi
    fi
fi

# 3. Import ECR Repository
echo "🐳 Importing ECR repository..."

if resource_exists_aws "aws ecr describe-repositories --region $AWS_REGION --repository-names bankapp-${ENVIRONMENT}"; then
    safe_import "aws_ecr_repository.app_repo" "bankapp-${ENVIRONMENT}" "ECR Repository"
    
    # Check if lifecycle policy exists
    if resource_exists_aws "aws ecr get-lifecycle-policy --region $AWS_REGION --repository-name bankapp-${ENVIRONMENT}"; then
        safe_import "aws_ecr_lifecycle_policy.app_repo_policy" "bankapp-${ENVIRONMENT}" "ECR Lifecycle Policy"
    fi
fi

# 4. Import Application Load Balancer and related resources
echo "⚖️  Importing ALB and related resources..."

if resource_exists_aws "aws elbv2 describe-load-balancers --region $AWS_REGION --names bankapp-${ENVIRONMENT}-alb"; then
    ALB_ARN=$(aws elbv2 describe-load-balancers --region $AWS_REGION --names "bankapp-${ENVIRONMENT}-alb" --query 'LoadBalancers[0].LoadBalancerArn' --output text)
    safe_import "aws_lb.app_alb" "$ALB_ARN" "Application Load Balancer"
    
    # Import ALB Listener
    LISTENER_ARN=$(aws elbv2 describe-listeners --region $AWS_REGION --load-balancer-arn "$ALB_ARN" --query 'Listeners[?Port==`80`].ListenerArn' --output text)
    if [ -n "$LISTENER_ARN" ] && [ "$LISTENER_ARN" != "None" ]; then
        safe_import "aws_lb_listener.app_listener" "$LISTENER_ARN" "ALB Listener"
    fi
fi

# Import Target Group
if resource_exists_aws "aws elbv2 describe-target-groups --region $AWS_REGION --names bankapp-${ENVIRONMENT}-tg"; then
    TG_ARN=$(aws elbv2 describe-target-groups --region $AWS_REGION --names "bankapp-${ENVIRONMENT}-tg" --query 'TargetGroups[0].TargetGroupArn' --output text)
    safe_import "aws_lb_target_group.app_tg" "$TG_ARN" "ALB Target Group"
fi

# Import ALB Security Group
if resource_exists_aws "aws ec2 describe-security-groups --region $AWS_REGION --filters 'Name=group-name,Values=bankapp-${ENVIRONMENT}-alb-*'"; then
    ALB_SG_ID=$(aws ec2 describe-security-groups --region $AWS_REGION --filters "Name=group-name,Values=bankapp-${ENVIRONMENT}-alb-*" --query 'SecurityGroups[0].GroupId' --output text)
    safe_import "aws_security_group.alb_sg" "$ALB_SG_ID" "ALB Security Group"
fi

# 5. Import RDS and related resources
echo "🗄️  Importing RDS and related resources..."

# Import RDS Subnet Group
if resource_exists_aws "aws rds describe-db-subnet-groups --region $AWS_REGION --db-subnet-group-name bankapp-${ENVIRONMENT}-db-subnet-group"; then
    safe_import "module.rds.aws_db_subnet_group.main" "bankapp-${ENVIRONMENT}-db-subnet-group" "RDS Subnet Group"
fi

# Import RDS Security Group
# Import RDS Security Group
if resource_exists_aws "aws ec2 describe-security-groups --region $AWS_REGION --filters 'Name=group-name,Values=bankapp-${ENVIRONMENT}-rds-*'"; then
  RDS_SG_ID=$(aws ec2 describe-security-groups --region $AWS_REGION --filters "Name=group-name,Values=bankapp-${ENVIRONMENT}-rds-*" --query 'SecurityGroups[0].GroupId' --output text)

  if [ -n "$RDS_SG_ID" ] && [ "$RDS_SG_ID" != "None" ]; then
    safe_import "module.rds.aws_security_group.rds_sg" "$RDS_SG_ID" "RDS Security Group"
  else
    echo "⚠️ No RDS Security Group found, skipping import."
  fi
fi



# Import RDS Instance
if resource_exists_aws "aws rds describe-db-instances --region $AWS_REGION --db-instance-identifier bankapp-${ENVIRONMENT}-db"; then
    safe_import "module.rds.aws_db_instance.main" "bankapp-${ENVIRONMENT}-db" "RDS Instance"
fi

# 6. Import additional security groups that might exist
echo "🔒 Importing additional security groups..."

# EKS Cluster Security Group
#if [ -n "$VPC_ID" ] && [ "$VPC_ID" != "null" ]; then
    #CLUSTER_SG_ID=$(aws ec2 describe-security-groups --region $AWS_REGION --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=*eks-cluster-sg-*" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "")
    #if [ -n "$CLUSTER_SG_ID" ] && [ "$CLUSTER_SG_ID" != "None" ]; then
    #    safe_import "module.eks.aws_security_group.cluster" "$CLUSTER_SG_ID" "EKS Cluster Security Group"
    #fi
    
    # EKS Node Security Group
    NODE_SG_ID=$(aws ec2 describe-security-groups --region $AWS_REGION --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=*eks-node-group-*" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "")
    if [ -n "$NODE_SG_ID" ] && [ "$NODE_SG_ID" != "None" ]; then
        safe_import "module.eks.aws_security_group.node" "$NODE_SG_ID" "EKS Node Security Group"
    fi
fi

# 7. Import Elastic IPs for NAT Gateways
echo "🌐 Importing Elastic IPs..."

if [ -n "$VPC_ID" ] && [ "$VPC_ID" != "null" ]; then
    NAT_EIP_IDS=$(aws ec2 describe-addresses --region $AWS_REGION --filters "Name=domain,Values=vpc" --query 'Addresses[?AssociationId!=null].AllocationId' --output text 2>/dev/null || echo "")
    if [ -n "$NAT_EIP_IDS" ] && [ "$NAT_EIP_IDS" != "None" ]; then
        EIP_COUNT=0
        for eip_id in $NAT_EIP_IDS; do
            safe_import "module.vpc.aws_eip.nat[$EIP_COUNT]" "$eip_id" "Elastic IP"
            EIP_COUNT=$((EIP_COUNT + 1))
        done
    fi
fi

# 8. Final state consistency check
echo "🔍 Running final state consistency check..."

# Refresh terraform state
terraform refresh -var="db_password=dummy" >/dev/null 2>&1 || echo "⚠️ State refresh had issues (this is often normal)"

# Validate configuration after imports
if terraform validate >/dev/null 2>&1; then
    echo "✅ Terraform configuration is valid after imports"
else
    echo "⚠️ Terraform configuration validation failed after imports"
fi

# Summary of imported resources
echo ""
echo "🎯 Resource import process completed!"
echo ""
echo "📊 Import Summary:"
echo "- Environment: $ENVIRONMENT"
echo "- Region: $AWS_REGION"
echo "- Account ID: $ACCOUNT_ID"
echo "- Working Directory: $TF_DIR"
echo ""

# List current state
echo "📋 Current Terraform State:"
terraform state list | head -20 | sed 's/^/  ✓ /' || echo "  ⚠️ Unable to list state"

if terraform state list | wc -l | grep -q "^[1-9]"; then
    echo ""
    echo "✅ Import process completed successfully!"
    echo "   $(terraform state list | wc -l) resources are now managed by Terraform"
else
    echo ""
    echo "⚠️ Import process completed but no resources in state"
    echo "   This might indicate import failures or no existing resources"
fi