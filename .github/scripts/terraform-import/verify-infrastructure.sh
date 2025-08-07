#!/bin/bash

set -e

ENVIRONMENT="$1"
AWS_REGION="$2"

echo "🔍 Verifying infrastructure for environment: $ENVIRONMENT"

# Initialize verification results
VERIFICATION_PASSED=true
VERIFICATION_RESULTS=""

# Function to verify resource and log results
verify_resource() {
    local resource_name="$1"
    local check_command="$2"
    local expected_status="$3"
    
    echo "🔍 Verifying $resource_name..."
    
    if eval "$check_command" >/dev/null 2>&1; then
        echo "✅ $resource_name: PASSED"
        VERIFICATION_RESULTS="${VERIFICATION_RESULTS}✅ $resource_name: PASSED\n"
    else
        echo "❌ $resource_name: FAILED"
        VERIFICATION_RESULTS="${VERIFICATION_RESULTS}❌ $resource_name: FAILED\n"
        VERIFICATION_PASSED=false
    fi
}

# Function to verify resource with detailed status
verify_resource_status() {
    local resource_name="$1"
    local check_command="$2"
    local status_command="$3"
    local expected_status="$4"
    
    echo "🔍 Verifying $resource_name status..."
    
    if eval "$check_command" >/dev/null 2>&1; then
        local actual_status=$(eval "$status_command" 2>/dev/null || echo "UNKNOWN")
        if [ "$actual_status" = "$expected_status" ]; then
            echo "✅ $resource_name: $actual_status (Expected: $expected_status)"
            VERIFICATION_RESULTS="${VERIFICATION_RESULTS}✅ $resource_name: $actual_status\n"
        else
            echo "⚠️  $resource_name: $actual_status (Expected: $expected_status)"
            VERIFICATION_RESULTS="${VERIFICATION_RESULTS}⚠️  $resource_name: $actual_status (Expected: $expected_status)\n"
        fi
    else
        echo "❌ $resource_name: NOT FOUND"
        VERIFICATION_RESULTS="${VERIFICATION_RESULTS}❌ $resource_name: NOT FOUND\n"
        VERIFICATION_PASSED=false
    fi
}

echo "🚀 Starting infrastructure verification process..."

# 1. Verify VPC
verify_resource "VPC" \
    "aws ec2 describe-vpcs --region $AWS_REGION --filters 'Name=tag:Name,Values=bankapp-${ENVIRONMENT}' --query 'Vpcs[0].VpcId'" \
    "exists"

# Get VPC ID for further checks
VPC_ID=$(aws ec2 describe-vpcs --region $AWS_REGION --filters "Name=tag:Name,Values=bankapp-${ENVIRONMENT}" --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "")

if [ -n "$VPC_ID" ] && [ "$VPC_ID" != "null" ] && [ "$VPC_ID" != "None" ]; then
    echo "📍 Using VPC ID: $VPC_ID"
    
    # 2. Verify Subnets
    verify_resource "Private Subnets" \
        "aws ec2 describe-subnets --region $AWS_REGION --filters 'Name=vpc-id,Values=$VPC_ID' 'Name=tag:Name,Values=*private*' --query 'Subnets[0].SubnetId'" \
        "exists"
    
    verify_resource "Public Subnets" \
        "aws ec2 describe-subnets --region $AWS_REGION --filters 'Name=vpc-id,Values=$VPC_ID' 'Name=tag:Name,Values=*public*' --query 'Subnets[0].SubnetId'" \
        "exists"
fi

# 3. Verify EKS Cluster
verify_resource_status "EKS Cluster" \
    "aws eks describe-cluster --region $AWS_REGION --name bankapp-${ENVIRONMENT}" \
    "aws eks describe-cluster --region $AWS_REGION --name bankapp-${ENVIRONMENT} --query 'cluster.status' --output text" \
    "ACTIVE"

# 4. Verify EKS Node Group
verify_resource_status "EKS Node Group" \
    "aws eks describe-nodegroup --region $AWS_REGION --cluster-name bankapp-${ENVIRONMENT} --nodegroup-name main" \
    "aws eks describe-nodegroup --region $AWS_REGION --cluster-name bankapp-${ENVIRONMENT} --nodegroup-name main --query 'nodegroup.status' --output text" \
    "ACTIVE"

# 5. Verify ECR Repository
verify_resource "ECR Repository" \
    "aws ecr describe-repositories --region $AWS_REGION --repository-names bankapp-${ENVIRONMENT}" \
    "exists"

# 6. Verify Application Load Balancer
verify_resource_status "Application Load Balancer" \
    "aws elbv2 describe-load-balancers --region $AWS_REGION --names bankapp-${ENVIRONMENT}-alb" \
    "aws elbv2 describe-load-balancers --region $AWS_REGION --names bankapp-${ENVIRONMENT}-alb --query 'LoadBalancers[0].State.Code' --output text" \
    "active"

# 7. Verify Target Group
verify_resource "ALB Target Group" \
    "aws elbv2 describe-target-groups --region $AWS_REGION --names bankapp-${ENVIRONMENT}-tg" \
    "exists"

# 8. Verify ALB Listener
ALB_ARN=$(aws elbv2 describe-load-balancers --region $AWS_REGION --names "bankapp-${ENVIRONMENT}-alb" --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || echo "")
if [ -n "$ALB_ARN" ] && [ "$ALB_ARN" != "null" ]; then
    verify_resource "ALB Listener (Port 80)" \
        "aws elbv2 describe-listeners --region $AWS_REGION --load-balancer-arn $ALB_ARN --query 'Listeners[?Port==\`80\`]'" \
        "exists"
fi

# 9. Verify Security Groups
verify_resource "ALB Security Group" \
    "aws ec2 describe-security-groups --region $AWS_REGION --filters 'Name=group-name,Values=bankapp-${ENVIRONMENT}-alb-*'" \
    "exists"

verify_resource "RDS Security Group" \
    "aws ec2 describe-security-groups --region $AWS_REGION --filters 'Name=group-name,Values=bankapp-${ENVIRONMENT}-rds-*'" \
    "exists"

# 10. Verify RDS Instance
verify_resource_status "RDS Database" \
    "aws rds describe-db-instances --region $AWS_REGION --db-instance-identifier bankapp-${ENVIRONMENT}-db" \
    "aws rds describe-db-instances --region $AWS_REGION --db-instance-identifier bankapp-${ENVIRONMENT}-db --query 'DBInstances[0].DBInstanceStatus' --output text" \
    "available"

# 11. Verify RDS Subnet Group
verify_resource "RDS Subnet Group" \
    "aws rds describe-db-subnet-groups --region $AWS_REGION --db-subnet-group-name bankapp-${ENVIRONMENT}-db-subnet-group" \
    "exists"

# 12. Verify EKS OIDC Provider
EKS_OIDC_ISSUER=$(aws eks describe-cluster --region $AWS_REGION --name "bankapp-${ENVIRONMENT}" --query 'cluster.identity.oidc.issuer' --output text 2>/dev/null || echo "")
if [ -n "$EKS_OIDC_ISSUER" ] && [ "$EKS_OIDC_ISSUER" != "null" ]; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    OIDC_PROVIDER_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${EKS_OIDC_ISSUER#https://}"
    
    verify_resource "EKS OIDC Provider" \
        "aws iam get-open-id-connect-provider --open-id-connect-provider-arn $OIDC_PROVIDER_ARN" \
        "exists"
fi

# 13. Verify Kubernetes connectivity (if EKS is active)
if aws eks describe-cluster --region $AWS_REGION --name "bankapp-${ENVIRONMENT}" --query 'cluster.status' --output text 2>/dev/null | grep -q "ACTIVE"; then
    echo "🔍 Verifying Kubernetes connectivity..."
    
    # Update kubeconfig
    if aws eks update-kubeconfig --region $AWS_REGION --name "bankapp-${ENVIRONMENT}" >/dev/null 2>&1; then
        # Test kubectl connectivity
        if kubectl cluster-info >/dev/null 2>&1; then
            echo "✅ Kubernetes Connectivity: PASSED"
            VERIFICATION_RESULTS="${VERIFICATION_RESULTS}✅ Kubernetes Connectivity: PASSED\n"
            
            # Check node readiness
            READY_NODES=$(kubectl get nodes --no-headers | grep -c "Ready" || echo "0")
            TOTAL_NODES=$(kubectl get nodes --no-headers | wc -l || echo "0")
            
            if [ "$READY_NODES" -gt 0 ] && [ "$READY_NODES" -eq "$TOTAL_NODES" ]; then
                echo "✅ EKS Nodes: $READY_NODES/$TOTAL_NODES Ready"
                VERIFICATION_RESULTS="${VERIFICATION_RESULTS}✅ EKS Nodes: $READY_NODES/$TOTAL_NODES Ready\n"
            else
                echo "⚠️  EKS Nodes: $READY_NODES/$TOTAL_NODES Ready"
                VERIFICATION_RESULTS="${VERIFICATION_RESULTS}⚠️  EKS Nodes: $READY_NODES/$TOTAL_NODES Ready\n"
            fi
        else
            echo "❌ Kubernetes Connectivity: FAILED"
            VERIFICATION_RESULTS="${VERIFICATION_RESULTS}❌ Kubernetes Connectivity: FAILED\n"
            VERIFICATION_PASSED=false
        fi
    else
        echo "❌ Kubeconfig Update: FAILED"
        VERIFICATION_RESULTS="${VERIFICATION_RESULTS}❌ Kubeconfig Update: FAILED\n"
        VERIFICATION_PASSED=false
    fi
fi

# 14. Verify Resource Tags
echo "🔍 Verifying resource tagging compliance..."
EXPECTED_TAGS="Environment=$ENVIRONMENT,Project=bankapp"

# Check VPC tags
if [ -n "$VPC_ID" ] && [ "$VPC_ID" != "null" ]; then
    VPC_ENV_TAG=$(aws ec2 describe-vpcs --region $AWS_REGION --vpc-ids "$VPC_ID" --query "Vpcs[0].Tags[?Key=='Environment'].Value" --output text 2>/dev/null || echo "")
    if [ "$VPC_ENV_TAG" = "$ENVIRONMENT" ]; then
        echo "✅ VPC Tags: Compliant"
        VERIFICATION_RESULTS="${VERIFICATION_RESULTS}✅ VPC Tags: Compliant\n"
    else
        echo "⚠️  VPC Tags: Missing or incorrect Environment tag"
        VERIFICATION_RESULTS="${VERIFICATION_RESULTS}⚠️  VPC Tags: Missing or incorrect Environment tag\n"
    fi
fi

# Final verification summary
echo ""
echo "🎯 Infrastructure Verification Complete!"
echo ""
echo "📊 Verification Results:"
echo -e "$VERIFICATION_RESULTS"

if [ "$VERIFICATION_PASSED" = true ]; then
    echo ""
    echo "🎉 All infrastructure verification checks PASSED!"
    echo ""
    echo "✅ Infrastructure Status: HEALTHY"
    echo "📍 Environment: $ENVIRONMENT"
    echo "📍 Region: $AWS_REGION"
    echo "⏰ Verified at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    exit 0
else
    echo ""
    echo "❌ Some infrastructure verification checks FAILED!"
    echo ""
    echo "🚨 Infrastructure Status: DEGRADED"
    echo "📍 Environment: $ENVIRONMENT"
    echo "📍 Region: $AWS_REGION"
    echo "⏰ Verified at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo ""
    echo "🔧 Recommended Actions:"
    echo "1. Review failed checks above"
    echo "2. Run terraform plan to identify issues"
    echo "3. Check AWS console for resource states"
    echo "4. Verify IAM permissions"
    echo "5. Check CloudWatch logs for errors"
    
    exit 1
fi