#!/bin/bash
set -e

ENVIRONMENT=$1
AWS_REGION=$2
TERRAFORM_DIR=${3:-.}

if [ -z "$ENVIRONMENT" ] || [ -z "$AWS_REGION" ]; then
    echo "Usage: $0 <environment> <aws_region> [terraform_dir]"
    exit 1
fi

cd "$TERRAFORM_DIR"

import_resource() {
    local terraform_address=$1
    local resource_id=$2
    local description=$3

    if terraform state list | grep -q "$terraform_address"; then
        echo "✅ $description already in Terraform state, skipping import."
        return
    fi

    if [ -n "$resource_id" ] && [ "$resource_id" != "None" ] && [ "$resource_id" != "null" ]; then
        echo "📦 Importing $description: $resource_id"
        terraform import "$terraform_address" "$resource_id" || true
    else
        echo "⏭️  Skipping $description - not found"
    fi
}

# --- EKS Cluster
if aws eks describe-cluster --name "bankapp-$ENVIRONMENT" --region "$AWS_REGION" >/dev/null 2>&1; then
    import_resource "module.eks.aws_eks_cluster.cluster" "bankapp-$ENVIRONMENT" "EKS Cluster"
fi

# --- EKS Node Groups
NODE_GROUPS=$(aws eks list-nodegroups --cluster-name "bankapp-$ENVIRONMENT" --region "$AWS_REGION" --query 'nodegroups' --output text)
for nodegroup in $NODE_GROUPS; do
    import_resource "module.eks.aws_eks_node_group.node_groups[\"$nodegroup\"]" "bankapp-$ENVIRONMENT:$nodegroup" "EKS Node Group: $nodegroup"
done

# --- ALB + Security Group
ALB_ARN=$(aws elbv2 describe-load-balancers --names "bankapp-$ENVIRONMENT-alb" --region "$AWS_REGION" --query 'LoadBalancers[0].LoadBalancerArn' --output text)
if [ "$ALB_ARN" != "None" ]; then
    import_resource "aws_lb.app_alb" "$ALB_ARN" "Application Load Balancer"

    # Import ALB SG
    ALB_SG=$(aws elbv2 describe-load-balancers --load-balancer-arns "$ALB_ARN" --region "$AWS_REGION" --query 'LoadBalancers[0].SecurityGroups[0]' --output text)
    import_resource "aws_security_group.alb_sg" "$ALB_SG" "ALB Security Group"
fi

# --- Target Group
TG_ARN=$(aws elbv2 describe-target-groups --names "bankapp-$ENVIRONMENT-tg" --region "$AWS_REGION" --query 'TargetGroups[0].TargetGroupArn' --output text)
import_resource "aws_lb_target_group.app_tg" "$TG_ARN" "Target Group"

# --- ALB Listener
LISTENER_ARN=$(aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" --region "$AWS_REGION" --query 'Listeners[0].ListenerArn' --output text)
import_resource "aws_lb_listener.app_listener" "$LISTENER_ARN" "ALB Listener"

# --- RDS Subnet Group + Subnets
if aws rds describe-db-subnet-groups --db-subnet-group-name "bankapp-$ENVIRONMENT-db-subnet-group" --region "$AWS_REGION" >/dev/null 2>&1; then
    import_resource "module.rds.aws_db_subnet_group.main" "bankapp-$ENVIRONMENT-db-subnet-group" "RDS Subnet Group"

    # Get VPC ID from the subnet group and import
    VPC_ID=$(aws rds describe-db-subnet-groups --db-subnet-group-name "bankapp-$ENVIRONMENT-db-subnet-group" --region "$AWS_REGION" --query 'DBSubnetGroups[0].VpcId' --output text)
    import_resource "module.vpc.aws_vpc.main" "$VPC_ID" "VPC for RDS"

    # Import each subnet
    SUBNET_IDS=$(aws rds describe-db-subnet-groups --db-subnet-group-name "bankapp-$ENVIRONMENT-db-subnet-group" --region "$AWS_REGION" --query 'DBSubnetGroups[0].Subnets[*].SubnetIdentifier' --output text)
    INDEX=0
    for subnet in $SUBNET_IDS; do
        import_resource "module.vpc.aws_subnet.private[$INDEX]" "$subnet" "Private Subnet $INDEX"
        INDEX=$((INDEX+1))
    done
fi

# --- RDS Instance
if aws rds describe-db-instances --db-instance-identifier "bankapp-$ENVIRONMENT-db" --region "$AWS_REGION" >/dev/null 2>&1; then
    import_resource "module.rds.aws_db_instance.main" "bankapp-$ENVIRONMENT-db" "RDS Instance"
fi

# --- ECR Repository
if aws ecr describe-repositories --repository-names "bankapp-$ENVIRONMENT" --region "$AWS_REGION" >/dev/null 2>&1; then
    import_resource "aws_ecr_repository.app_repo" "bankapp-$ENVIRONMENT" "ECR Repository"
fi

echo "✅ Import process completed for environment: $ENVIRONMENT"
