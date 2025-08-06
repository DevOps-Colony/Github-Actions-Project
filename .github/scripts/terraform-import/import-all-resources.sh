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

echo "🔄 Importing AWS resources for bankapp-$ENVIRONMENT in $AWS_REGION"

# Utility: import if not in state
import_if_missing() {
    local tf_address=$1
    local aws_id=$2
    local desc=$3

    if terraform state list | grep -q "$tf_address"; then
        echo "✅ $desc already in Terraform state"
    elif [ -n "$aws_id" ] && [ "$aws_id" != "None" ] && [ "$aws_id" != "null" ]; then
        echo "📦 Importing $desc ($aws_id)"
        terraform import "$tf_address" "$aws_id" || true
    else
        echo "⏭️ Skipping $desc - not found"
    fi
}

# --- VPC ---
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=bankapp-$ENVIRONMENT" \
  --region "$AWS_REGION" --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "")
import_if_missing "module.vpc.aws_vpc.main" "$VPC_ID" "VPC"

# --- Public Subnets ---
PUB_SUBNETS=$(aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=bankapp-$ENVIRONMENT-public-*" \
  --region "$AWS_REGION" --query 'Subnets[].SubnetId' --output text)
i=0
for subnet in $PUB_SUBNETS; do
  import_if_missing "module.vpc.aws_subnet.public[$i]" "$subnet" "Public Subnet $i"
  i=$((i+1))
done

# --- Private Subnets ---
PRIV_SUBNETS=$(aws ec2 describe-subnets \
  --filters "Name=tag:Name,Values=bankapp-$ENVIRONMENT-private-*" \
  --region "$AWS_REGION" --query 'Subnets[].SubnetId' --output text)
i=0
for subnet in $PRIV_SUBNETS; do
  import_if_missing "module.vpc.aws_subnet.private[$i]" "$subnet" "Private Subnet $i"
  i=$((i+1))
done

# --- EKS Cluster ---
import_if_missing "module.eks.aws_eks_cluster.cluster" "bankapp-$ENVIRONMENT" "EKS Cluster"

# --- Node Group Role ---
import_if_missing "module.eks.aws_iam_role.node_group" "bankapp-$ENVIRONMENT-node-group-role" "EKS Node Group Role"

# --- Node Groups ---
NODE_GROUPS=$(aws eks list-nodegroups --cluster-name "bankapp-$ENVIRONMENT" --region "$AWS_REGION" --query 'nodegroups' --output text)
for ng in $NODE_GROUPS; do
  import_if_missing "module.eks.aws_eks_node_group.node_groups[\"$ng\"]" "bankapp-$ENVIRONMENT:$ng" "EKS Node Group $ng"
done

# --- ALB Security Group ---
ALB_SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=bankapp-$ENVIRONMENT-alb-sg" \
  --region "$AWS_REGION" --query 'SecurityGroups[0].GroupId' --output text)
import_if_missing "aws_security_group.alb_sg" "$ALB_SG_ID" "ALB Security Group"

# --- ALB ---
ALB_ARN=$(aws elbv2 describe-load-balancers --names "bankapp-$ENVIRONMENT-alb" --region "$AWS_REGION" --query 'LoadBalancers[0].LoadBalancerArn' --output text)
import_if_missing "aws_lb.app_alb" "$ALB_ARN" "Application Load Balancer"

# --- Target Group ---
TG_ARN=$(aws elbv2 describe-target-groups --names "bankapp-$ENVIRONMENT-tg" --region "$AWS_REGION" --query 'TargetGroups[0].TargetGroupArn' --output text)
import_if_missing "aws_lb_target_group.app_tg" "$TG_ARN" "Target Group"

# --- Listener ---
if [ "$ALB_ARN" != "None" ] && [ "$ALB_ARN" != "null" ]; then
  LISTENER_ARN=$(aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" --region "$AWS_REGION" --query 'Listeners[0].ListenerArn' --output text)
  import_if_missing "aws_lb_listener.app_listener" "$LISTENER_ARN" "ALB Listener"
fi

# --- ECR Repository ---
import_if_missing "aws_ecr_repository.app_repo" "bankapp-$ENVIRONMENT" "ECR Repository"

# --- RDS Subnet Group ---
import_if_missing "module.rds.aws_db_subnet_group.main" "bankapp-$ENVIRONMENT-db-subnet-group" "RDS Subnet Group"

# --- RDS Instance ---
import_if_missing "module.rds.aws_db_instance.main" "bankapp-$ENVIRONMENT-db" "RDS Instance"

echo "✅ Import completed for $ENVIRONMENT"
