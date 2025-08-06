#!/bin/bash
set -e

ENVIRONMENT=$1
AWS_REGION=$2
TERRAFORM_DIR=${3:-.}

if [ -z "$ENVIRONMENT" ] || [ -z "$AWS_REGION" ]; then
    echo "Usage: $0 <environment> <aws_region> [terraform_dir]"
    echo "Example: $0 staging us-west-2 ."
    exit 1
fi

echo "🔄 Starting comprehensive import for environment: $ENVIRONMENT"
echo "📍 Region: $AWS_REGION"
echo "📁 Terraform directory: $TERRAFORM_DIR"

cd "$TERRAFORM_DIR"

# Function to safely import a resource
import_resource() {
    local resource_type=$1
    local terraform_address=$2
    local resource_id=$3
    local description=$4
    
    if [ ! -z "$resource_id" ] && [ "$resource_id" != "None" ] && [ "$resource_id" != "null" ]; then
        echo "📦 Importing $description: $resource_id"
        terraform import "$terraform_address" "$resource_id" 2>/dev/null || true
    else
        echo "⏭️  Skipping $description - not found"
    fi
}

# Import EKS Cluster
echo "🔍 Checking EKS cluster..."
if aws eks describe-cluster --name "bankapp-$ENVIRONMENT" --region "$AWS_REGION" >/dev/null 2>&1; then
    import_resource "EKS Cluster" "module.eks.aws_eks_cluster.cluster" "bankapp-$ENVIRONMENT" "EKS Cluster"
fi

# Import EKS Node Groups
echo "🔍 Checking EKS node groups..."
NODE_GROUPS=$(aws eks list-nodegroups --cluster-name "bankapp-$ENVIRONMENT" --region "$AWS_REGION" --query 'nodegroups' --output text 2>/dev/null || echo "")
if [ ! -z "$NODE_GROUPS" ] && [ "$NODE_GROUPS" != "None" ]; then
    for nodegroup in $NODE_GROUPS; do
        import_resource "Node Group" "module.eks.aws_eks_node_group.node_group" "bankapp-$ENVIRONMENT:$nodegroup" "Node Group: $nodegroup"
    done
fi

# Import ALB
echo "🔍 Checking Application Load Balancer..."
ALB_ARN=$(aws elbv2 describe-load-balancers --names "bankapp-$ENVIRONMENT-alb" --region "$AWS_REGION" --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || echo "None")
import_resource "ALB" "aws_lb.app_alb" "$ALB_ARN" "Application Load Balancer"

# Import Target Group
echo "🔍 Checking Target Group..."
TG_ARN=$(aws elbv2 describe-target-groups --names "bankapp-$ENVIRONMENT-tg" --region "$AWS_REGION" --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || echo "None")
import_resource "Target Group" "aws_lb_target_group.app_tg" "$TG_ARN" "Target Group"

# Import ALB Listener
echo "🔍 Checking ALB Listener..."
if [ "$ALB_ARN" != "None" ] && [ "$ALB_ARN" != "null" ]; then
    LISTENER_ARN=$(aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" --region "$AWS_REGION" --query 'Listeners[0].ListenerArn' --output text 2>/dev/null || echo "None")
    import_resource "ALB Listener" "aws_lb_listener.app_listener" "$LISTENER_ARN" "ALB Listener"
fi

# Import RDS Subnet Group
echo "🔍 Checking RDS Subnet Group..."
if aws rds describe-db-subnet-groups --db-subnet-group-name "bankapp-$ENVIRONMENT-db-subnet-group" --region "$AWS_REGION" >/dev/null 2>&1; then
    import_resource "RDS Subnet Group" "module.rds.aws_db_subnet_group.main" "bankapp-$ENVIRONMENT-db-subnet-group" "RDS Subnet Group"
fi

# Import RDS Instance
echo "🔍 Checking RDS Instance..."
if aws rds describe-db-instances --db-instance-identifier "bankapp-$ENVIRONMENT-db" --region "$AWS_REGION" >/dev/null 2>&1; then
    import_resource "RDS Instance" "module.rds.aws_db_instance.main" "bankapp-$ENVIRONMENT-db" "RDS Instance"
fi

# Import ECR Repository
echo "🔍 Checking ECR Repository..."
if aws ecr describe-repositories --repository-names "bankapp-$ENVIRONMENT" --region "$AWS_REGION" >/dev/null 2>&1; then
    import_resource "ECR Repository" "aws_ecr_repository.app_repo" "bankapp-$ENVIRONMENT" "ECR Repository"
fi

# Import VPC (if managed by Terraform)
echo "🔍 Checking VPC..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=bankapp-$ENVIRONMENT-vpc" --region "$AWS_REGION" --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "None")
if [ "$VPC_ID" != "None" ] && [ "$VPC_ID" != "null" ]; then
    import_resource "VPC" "module.vpc.aws_vpc.main" "$VPC_ID" "VPC"
    
    # Import Security Groups
    EKS_SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=bankapp-$ENVIRONMENT-eks-sg" --region "$AWS_REGION" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "None")
    import_resource "EKS Security Group" "module.eks.aws_security_group.eks_sg" "$EKS_SG_ID" "EKS Security Group"
    
    ALB_SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=bankapp-$ENVIRONMENT-alb-sg" --region "$AWS_REGION" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "None")
    import_resource "ALB Security Group" "aws_security_group.alb_sg" "$ALB_SG_ID" "ALB Security Group"
fi

# Import IAM Roles (common ones)
echo "🔍 Checking IAM Roles..."
if aws iam get-role --role-name "bankapp-$ENVIRONMENT-node-group-role" --region "$AWS_REGION" >/dev/null 2>&1; then
    import_resource "IAM Role" "module.eks.aws_iam_role.node_group" "bankapp-$ENVIRONMENT-node-group-role" "EKS Node Group IAM Role"
fi

echo "✅ Import process completed for environment: $ENVIRONMENT"
echo "📊 Next steps:"
echo "   1. Run 'terraform plan' to see what changes are needed"
echo "   2. Run 'terraform apply' to apply any remaining changes"
