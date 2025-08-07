#!/bin/bash

set -e

ENVIRONMENT="$1"
AWS_REGION="$2"
TF_DIR="$3"

echo "🚀 Applying infrastructure with smart recovery for environment: $ENVIRONMENT"

cd "$TF_DIR"

# Function to apply with targeted recovery
apply_with_recovery() {
    local max_retries=3
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        echo "🎯 Apply attempt $((retry_count + 1)) of $max_retries"
        
        if terraform apply -auto-approve tfplan; then
            echo "✅ Terraform apply completed successfully"
            return 0
        else
            local exit_code=$?
            retry_count=$((retry_count + 1))
            
            echo "❌ Apply failed with exit code: $exit_code"
            
            if [ $retry_count -lt $max_retries ]; then
                echo "🔧 Attempting recovery actions..."
                
                # Analyze the error and attempt targeted recovery
                recover_from_apply_failure "$exit_code"
                
                # Regenerate plan after recovery
                echo "📋 Regenerating terraform plan after recovery..."
                terraform plan -out=tfplan
                
                echo "⏳ Waiting 15 seconds before retry..."
                sleep 15
            else
                echo "💥 All retry attempts exhausted"
                return $exit_code
            fi
        fi
    done
}

# Function to handle specific failure scenarios
recover_from_apply_failure() {
    local exit_code="$1"
    
    echo "🔍 Analyzing failure and attempting recovery..."
    
    # Get the last few lines of terraform output for error analysis
    # Since we can't capture terraform output directly, we'll use common recovery patterns
    
    # Common recovery pattern 1: Security group conflicts
    echo "🔧 Checking for security group conflicts..."
    if aws ec2 describe-security-groups --region "$AWS_REGION" --filters "Name=group-name,Values=bankapp-${ENVIRONMENT}-alb-*" --query 'SecurityGroups[0].GroupId' --output text >/dev/null 2>&1; then
        local sg_id=$(aws ec2 describe-security-groups --region "$AWS_REGION" --filters "Name=group-name,Values=bankapp-${ENVIRONMENT}-alb-*" --query 'SecurityGroups[0].GroupId' --output text)
        echo "🔧 Found existing ALB security group: $sg_id"
        
        # Try to import it
        terraform import aws_security_group.alb_sg "$sg_id" 2>/dev/null || echo "⚠️ Could not import security group (may already be imported)"
    fi
    
    # Common recovery pattern 2: Load balancer conflicts
    echo "🔧 Checking for load balancer conflicts..."
    if aws elbv2 describe-load-balancers --region "$AWS_REGION" --names "bankapp-${ENVIRONMENT}-alb" --query 'LoadBalancers[0].LoadBalancerArn' --output text >/dev/null 2>&1; then
        local alb_arn=$(aws elbv2 describe-load-balancers --region "$AWS_REGION" --names "bankapp-${ENVIRONMENT}-alb" --query 'LoadBalancers[0].LoadBalancerArn' --output text)
        echo "🔧 Found existing ALB: $alb_arn"
        
        # Try to import it
        terraform import aws_lb.app_alb "$alb_arn" 2>/dev/null || echo "⚠️ Could not import ALB (may already be imported)"
    fi
    
    # Common recovery pattern 3: Target group conflicts
    echo "🔧 Checking for target group conflicts..."
    if aws elbv2 describe-target-groups --region "$AWS_REGION" --names "bankapp-${ENVIRONMENT}-tg" --query 'TargetGroups[0].TargetGroupArn' --output text >/dev/null 2>&1; then
        local tg_arn=$(aws elbv2 describe-target-groups --region "$AWS_REGION" --names "bankapp-${ENVIRONMENT}-tg" --query 'TargetGroups[0].TargetGroupArn' --output text)
        echo "🔧 Found existing target group: $tg_arn"
        
        # Try to import it
        terraform import aws_lb_target_group.app_tg "$tg_arn" 2>/dev/null || echo "⚠️ Could not import target group (may already be imported)"
    fi
    
    # Common recovery pattern 4: RDS subnet group VPC conflicts
    echo "🔧 Checking for RDS subnet group conflicts..."
    if aws rds describe-db-subnet-groups --region "$AWS_REGION" --db-subnet-group-name "bankapp-${ENVIRONMENT}-db-subnet-group" >/dev/null 2>&1; then
        local subnet_group_vpc=$(aws rds describe-db-subnet-groups --region "$AWS_REGION" --db-subnet-group-name "bankapp-${ENVIRONMENT}-db-subnet-group" --query 'DBSubnetGroups[0].VpcId' --output text)
        local current_vpc=$(terraform show -json | jq -r '.values.root_module.resources[] | select(.type == "aws_vpc" and .name == "main") | .values.id' 2>/dev/null || echo "")
        
        if [ -n "$current_vpc" ] && [ "$subnet_group_vpc" != "$current_vpc" ]; then
            echo "⚠️ RDS subnet group VPC mismatch detected, removing conflicted resources"
            terraform state rm module.rds.aws_db_subnet_group.main 2>/dev/null || true
            
            # Delete the existing subnet group to allow recreation
            aws rds delete-db-subnet-group --db-subnet-group-name "bankapp-${ENVIRONMENT}-db-subnet-group" --region "$AWS_REGION" 2>/dev/null || echo "⚠️ Could not delete existing subnet group"
            
            # Wait for deletion
            echo "⏳ Waiting for subnet group deletion..."
            sleep 30
        fi
    fi
    
    # Common recovery pattern 5: EKS cluster OIDC provider conflicts
    echo "🔧 Checking for EKS OIDC provider conflicts..."
    if aws eks describe-cluster --region "$AWS_REGION" --name "bankapp-${ENVIRONMENT}" >/dev/null 2>&1; then
        local oidc_issuer=$(aws eks describe-cluster --region "$AWS_REGION" --name "bankapp-${ENVIRONMENT}" --query 'cluster.identity.oidc.issuer' --output text)
        if [ "$oidc_issuer" != "null" ] && [ -n "$oidc_issuer" ]; then
            local oidc_provider_arn="arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):oidc-provider/${oidc_issuer#https://}"
            
            # Try to import OIDC provider
            if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$oidc_provider_arn" >/dev/null 2>&1; then
                terraform import module.eks.aws_iam_openid_connect_provider.oidc_provider "$oidc_provider_arn" 2>/dev/null || echo "⚠️ Could not import OIDC provider"
            fi
        fi
    fi
    
    # Force refresh terraform state
    echo "🔄 Refreshing terraform state..."
    terraform refresh -var="db_password=dummy" 2>/dev/null || echo "⚠️ State refresh had issues"
}

# Function to verify apply success
verify_apply_success() {
    echo "🔍 Verifying apply success..."
    
    # Check critical resources
    local critical_resources=(
        "module.vpc"
        "module.eks"
        "aws_ecr_repository.app_repo"
    )
    
    for resource in "${critical_resources[@]}"; do
        if terraform state show "$resource" >/dev/null 2>&1; then
            echo "✅ $resource exists in state"
        else
            echo "❌ $resource missing from state"
            return 1
        fi
    done
    
    # Verify AWS resources exist
    echo "🔍 Verifying AWS resources..."
    
    # Check EKS cluster
    if aws eks describe-cluster --region "$AWS_REGION" --name "bankapp-${ENVIRONMENT}" >/dev/null 2>&1; then
        echo "✅ EKS cluster exists"
    else
        echo "❌ EKS cluster missing"
        return 1
    fi
    
    # Check ECR repository
    if aws ecr describe-repositories --region "$AWS_REGION" --repository-names "bankapp-${ENVIRONMENT}" >/dev/null 2>&1; then
        echo "✅ ECR repository exists"
    else
        echo "❌ ECR repository missing"
        return 1
    fi
    
    echo "✅ Apply verification completed successfully"
    return 0
}

# Main execution
echo "🚀 Starting terraform apply with recovery..."

# Pre-apply checks
echo "🔍 Running pre-apply checks..."

# Check if terraform plan exists
if [ ! -f "tfplan" ]; then
    echo "❌ No terraform plan found. Generating plan..."
    terraform plan -out=tfplan
fi

# Check terraform configuration is valid
if ! terraform validate; then
    echo "❌ Terraform configuration is invalid"
    exit 1
fi

# Execute apply with recovery
apply_with_recovery

# Post-apply verification
if verify_apply_success; then
    echo "🎉 Infrastructure apply completed successfully with verification!"
    
    # Output summary
    echo ""
    echo "📊 Apply Summary:"
    echo "- Environment: $ENVIRONMENT"
    echo "- Region: $AWS_REGION"
    echo "- Terraform Directory: $TF_DIR"
    echo "- Status: ✅ SUCCESS"
    
else
    echo "❌ Apply completed but verification failed"
    exit 1
fi