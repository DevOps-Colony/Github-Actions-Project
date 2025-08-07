#!/bin/bash

set -e

ENVIRONMENT="$1"
AWS_REGION="$2"

echo "🔍 Discovering existing resources for environment: $ENVIRONMENT" >&2

# Initialize discovery results
DISCOVERY_RESULTS="{}"

# Function to safely check resource existence
check_resource() {
    local resource_type="$1"
    local query="$2"
    local resource_name="$3"
    
    result=$(eval "$query" 2>/dev/null || echo "null")
    if [ "$result" != "null" ] && [ "$result" != "" ] && [ "$result" != "None" ]; then
        DISCOVERY_RESULTS=$(echo "$DISCOVERY_RESULTS" | jq --arg type "$resource_type" --arg name "$resource_name" --arg id "$result" '. + {($type): {name: $name, id: $id, exists: true}}')
        echo "✅ Found $resource_type: $resource_name ($result)" >&2
    else
        DISCOVERY_RESULTS=$(echo "$DISCOVERY_RESULTS" | jq --arg type "$resource_type" --arg name "$resource_name" '. + {($type): {name: $name, id: null, exists: false}}')
        echo "❌ Not found $resource_type: $resource_name" >&2
    fi
}

# Discover VPC
check_resource "vpc" \
    "aws ec2 describe-vpcs --region $AWS_REGION --filters 'Name=tag:Name,Values=bankapp-${ENVIRONMENT}' --query 'Vpcs[0].VpcId' --output text" \
    "bankapp-${ENVIRONMENT}"

# Get VPC ID for further queries
VPC_ID=$(echo "$DISCOVERY_RESULTS" | jq -r '.vpc.id // empty')

if [ -n "$VPC_ID" ] && [ "$VPC_ID" != "null" ]; then
    # Discover Subnets
    check_resource "private_subnets" \
        "aws ec2 describe-subnets --region $AWS_REGION --filters 'Name=vpc-id,Values=$VPC_ID' 'Name=tag:Name,Values=*private*' --query 'Subnets[*].SubnetId' --output text" \
        "private subnets"
    
    check_resource "public_subnets" \
        "aws ec2 describe-subnets --region $AWS_REGION --filters 'Name=vpc-id,Values=$VPC_ID' 'Name=tag:Name,Values=*public*' --query 'Subnets[*].SubnetId' --output text" \
        "public subnets"
fi

# Discover EKS Cluster
check_resource "eks_cluster" \
    "aws eks describe-cluster --region $AWS_REGION --name bankapp-${ENVIRONMENT} --query 'cluster.name' --output text" \
    "bankapp-${ENVIRONMENT}"

# Discover ECR Repository
check_resource "ecr_repository" \
    "aws ecr describe-repositories --region $AWS_REGION --repository-names bankapp-${ENVIRONMENT} --query 'repositories[0].repositoryName' --output text" \
    "bankapp-${ENVIRONMENT}"

# Discover Application Load Balancer
check_resource "alb" \
    "aws elbv2 describe-load-balancers --region $AWS_REGION --names bankapp-${ENVIRONMENT}-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text" \
    "bankapp-${ENVIRONMENT}-alb"

# Discover ALB Security Group
check_resource "alb_security_group" \
    "aws ec2 describe-security-groups --region $AWS_REGION --filters 'Name=group-name,Values=bankapp-${ENVIRONMENT}-alb-*' --query 'SecurityGroups[0].GroupId' --output text" \
    "ALB Security Group"

# Discover Target Group
check_resource "target_group" \
    "aws elbv2 describe-target-groups --region $AWS_REGION --names bankapp-${ENVIRONMENT}-tg --query 'TargetGroups[0].TargetGroupArn' --output text" \
    "bankapp-${ENVIRONMENT}-tg"

# Discover RDS Instance
check_resource "rds_instance" \
    "aws rds describe-db-instances --region $AWS_REGION --db-instance-identifier bankapp-${ENVIRONMENT}-db --query 'DBInstances[0].DBInstanceIdentifier' --output text" \
    "bankapp-${ENVIRONMENT}-db"

# Discover RDS Subnet Group
check_resource "rds_subnet_group" \
    "aws rds describe-db-subnet-groups --region $AWS_REGION --db-subnet-group-name bankapp-${ENVIRONMENT}-db-subnet-group --query 'DBSubnetGroups[0].DBSubnetGroupName' --output text" \
    "bankapp-${ENVIRONMENT}-db-subnet-group"

# Discover RDS Security Group
check_resource "rds_security_group" \
    "aws ec2 describe-security-groups --region $AWS_REGION --filters 'Name=group-name,Values=bankapp-${ENVIRONMENT}-rds-*' --query 'SecurityGroups[0].GroupId' --output text" \
    "RDS Security Group"

# Add metadata
DISCOVERY_RESULTS=$(echo "$DISCOVERY_RESULTS" | jq --arg env "$ENVIRONMENT" --arg region "$AWS_REGION" --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '. + {metadata: {environment: $env, region: $region, discovery_time: $timestamp}}')

# Output results
echo "$DISCOVERY_RESULTS"