#!/bin/bash

set -e

ENVIRONMENT="$1"
AWS_REGION="$2"
TF_DIR="$3"

echo "📦 Importing Kubernetes resources for environment: $ENVIRONMENT"

cd "$TF_DIR"

NAMESPACE="bankapp-${ENVIRONMENT}"

# Function to safely import Kubernetes resource
safe_k8s_import() {
    local tf_resource="$1"
    local k8s_resource_id="$2"
    local resource_type="$3"
    
    echo "🔍 Checking if $resource_type exists: $k8s_resource_id"
    
    # Check if resource exists in Kubernetes
    if kubectl get "$k8s_resource_id" >/dev/null 2>&1; then
        echo "📦 Attempting to import $tf_resource"
        if terraform import "$tf_resource" "$k8s_resource_id" 2>/dev/null; then
            echo "✅ Successfully imported $tf_resource"
        else
            echo "⚠️  Resource $tf_resource might already be in state"
        fi
    else
        echo "❌ Kubernetes resource $k8s_resource_id not found, skipping import"
    fi
}

# Function to safely import IAM resource
safe_iam_import() {
    local tf_resource="$1"
    local iam_resource_name="$2"
    local resource_type="$3"
    
    echo "🔍 Checking if $resource_type exists: $iam_resource_name"
    
    # Check based on resource type
    local check_command=""
    case "$resource_type" in
        "iam_role")
            check_command="aws iam get-role --role-name $iam_resource_name"
            ;;
        "iam_policy")
            local account_id=$(aws sts get-caller-identity --query Account --output text)
            check_command="aws iam get-policy --policy-arn arn:aws:iam::${account_id}:policy/${iam_resource_name}"
            iam_resource_name="arn:aws:iam::${account_id}:policy/${iam_resource_name}"
            ;;
    esac
    
    if eval "$check_command" >/dev/null 2>&1; then
        echo "📦 Attempting to import $tf_resource"
        if terraform import "$tf_resource" "$iam_resource_name" 2>/dev/null; then
            echo "✅ Successfully imported $tf_resource"
        else
            echo "⚠️  Resource $tf_resource might already be in state"
        fi
    else
        echo "❌ IAM resource $iam_resource_name not found, skipping import"
    fi
}

# Function to safely import Helm release
safe_helm_import() {
    local tf_resource="$1"
    local release_name="$2"
    local release_namespace="$3"
    
    echo "🔍 Checking if Helm release exists: $release_name in namespace $release_namespace"
    
    if helm status "$release_name" -n "$release_namespace" >/dev/null 2>&1; then
        echo "📦 Attempting to import Helm release $tf_resource"
        if terraform import "$tf_resource" "${release_namespace}/${release_name}" 2>/dev/null; then
            echo "✅ Successfully imported Helm release $tf_resource"
        else
            echo "⚠️  Helm release $tf_resource might already be in state"
        fi
    else
        echo "❌ Helm release $release_name not found in namespace $release_namespace"
    fi
}

echo "🔧 Starting Kubernetes resources import process..."

# Import namespace if it exists
safe_k8s_import "kubernetes_namespace.app_namespace" "$NAMESPACE" "namespace"

# Import database secret if it exists
safe_k8s_import "kubernetes_secret.db_secret" "secret/db-secret" "secret"

# Import AWS Load Balancer Controller service account
safe_k8s_import "kubernetes_service_account.aws_load_balancer_controller" "serviceaccount/aws-load-balancer-controller -n kube-system" "service account"

# Import AWS Load Balancer Controller IAM role
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_LBC_ROLE_NAME="bankapp-${ENVIRONMENT}-aws-load-balancer-controller"
safe_iam_import "aws_iam_role.aws_load_balancer_controller" "$AWS_LBC_ROLE_NAME" "iam_role"

# Import IAM role policy attachment for AWS Load Balancer Controller
AWS_LBC_POLICY_NAME="AWSLoadBalancerControllerIAMPolicy"
if aws iam get-policy --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/${AWS_LBC_POLICY_NAME}" >/dev/null 2>&1; then
    echo "📦 Attempting to import IAM role policy attachment"
    if terraform import "aws_iam_role_policy_attachment.aws_load_balancer_controller" "${AWS_LBC_ROLE_NAME}/arn:aws:iam::${ACCOUNT_ID}:policy/${AWS_LBC_POLICY_NAME}" 2>/dev/null; then
        echo "✅ Successfully imported IAM role policy attachment"
    else
        echo "⚠️  IAM role policy attachment might already be in state"
    fi
fi

# Import Helm releases
safe_helm_import "helm_release.aws_load_balancer_controller" "aws-load-balancer-controller" "kube-system"
safe_helm_import "helm_release.metrics_server" "metrics-server" "kube-system"

# Import cluster info config map
safe_k8s_import "kubernetes_config_map.cluster_info" "configmap/cluster-info -n $NAMESPACE" "config map"

# Check for any additional custom resources that might exist
echo "🔍 Checking for additional resources in namespace $NAMESPACE..."

# List all resources in the namespace for manual review
if kubectl get all -n "$NAMESPACE" >/dev/null 2>&1; then
    echo "📋 Current resources in namespace $NAMESPACE:"
    kubectl get all -n "$NAMESPACE" --no-headers | head -10 || true
else
    echo "❌ Namespace $NAMESPACE doesn't exist or is empty"
fi

# Check for any existing ingress resources
if kubectl get ingress -n "$NAMESPACE" >/dev/null 2>&1; then
    echo "📋 Existing ingress resources in namespace $NAMESPACE:"
    kubectl get ingress -n "$NAMESPACE" --no-headers || true
fi

# Check for existing secrets beyond the ones we're managing
if kubectl get secrets -n "$NAMESPACE" >/dev/null 2>&1; then
    echo "📋 Existing secrets in namespace $NAMESPACE:"
    kubectl get secrets -n "$NAMESPACE" --no-headers | grep -v "default-token" | head -5 || true
fi

# Verify Helm repositories are available
echo "🔍 Verifying Helm repositories..."

# Add required Helm repositories if they don't exist
if ! helm repo list | grep -q "https://aws.github.io/eks-charts"; then
    echo "📦 Adding AWS EKS Helm repository..."
    helm repo add eks https://aws.github.io/eks-charts
fi

if ! helm repo list | grep -q "https://kubernetes-sigs.github.io/metrics-server"; then
    echo "📦 Adding Metrics Server Helm repository..."
    helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
fi

# Update Helm repositories
echo "🔄 Updating Helm repositories..."
helm repo update

# Final validation
echo "🔍 Running final validation..."

# Check if kubectl context is correct
CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "none")
echo "📍 Current kubectl context: $CURRENT_CONTEXT"

# Check if we can communicate with the cluster
if kubectl cluster-info >/dev/null 2>&1; then
    echo "✅ Successfully connected to Kubernetes cluster"
else
    echo "❌ Cannot connect to Kubernetes cluster"
    exit 1
fi

echo "🎯 Kubernetes resources import process completed!"

# Summary of import actions
echo ""
echo "📊 Import Summary:"
echo "- Environment: $ENVIRONMENT"
echo "- Namespace: $NAMESPACE"
echo "- Region: $AWS_REGION"
echo "- kubectl Context: $CURRENT_CONTEXT"
echo "- Status: ✅ COMPLETED"