#!/bin/bash
CLUSTER_NAME=$1
AWS_REGION=$2
TERRAFORM_DIR=$3

echo "Attempting to import EKS cluster: $CLUSTER_NAME"
cd "$TERRAFORM_DIR"

terraform import module.eks.aws_eks_cluster.cluster "$CLUSTER_NAME" || true
