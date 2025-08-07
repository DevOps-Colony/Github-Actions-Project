# Cluster outputs
output "cluster_id" {
  description = "The name/id of the EKS cluster"
  value       = aws_eks_cluster.cluster.id
}

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = aws_eks_cluster.cluster.arn
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.cluster.endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id
}

output "cluster_iam_role_name" {
  description = "IAM role name associated with EKS cluster"
  value       = aws_iam_role.cluster.name
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN associated with EKS cluster"
  value       = aws_iam_role.cluster.arn
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.cluster.certificate_authority[0].data
}

output "cluster_version" {
  description = "The Kubernetes version for the EKS cluster"
  value       = aws_eks_cluster.cluster.version
}

output "cluster_status" {
  description = "Status of the EKS cluster. One of `CREATING`, `ACTIVE`, `DELETING`, `FAILED`"
  value       = aws_eks_cluster.cluster.status
}

# OIDC outputs
output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider if enabled"
  value       = aws_iam_openid_connect_provider.cluster.arn
}

# Node groups outputs
output "node_groups" {
  description = "EKS node groups"
  value       = aws_eks_node_group.node_groups
  sensitive   = false
}

output "node_security_group_id" {
  description = "ID of the node shared security group"
  value       = aws_security_group.node_sg.id
}

output "node_security_group_arn" {
  description = "Amazon Resource Name (ARN) of the node shared security group"
  value       = aws_security_group.node_sg.arn
}

# IAM role outputs for service accounts
output "aws_load_balancer_controller_role_arn" {
  description = "ARN of the AWS Load Balancer Controller IAM role"
  value       = var.enable_aws_load_balancer_controller ? aws_iam_role.aws_load_balancer_controller[0].arn : null
}

output "ebs_csi_driver_role_arn" {
  description = "ARN of the EBS CSI Driver IAM role"
  value       = var.enable_ebs_csi_driver ? aws_iam_role.ebs_csi_driver[0].arn : null
}

# KMS outputs
output "kms_key_arn" {
  description = "The Amazon Resource Name (ARN) of the key"
  value       = var.enable_secrets_encryption ? aws_kms_key.eks[0].arn : null
}

output "kms_key_id" {
  description = "The globally unique identifier for the key"
  value       = var.enable_secrets_encryption ? aws_kms_key.eks[0].key_id : null
}

# CloudWatch outputs
output "cloudwatch_log_group_name" {
  description = "Name of cloudwatch log group created"
  value       = aws_cloudwatch_log_group.cluster.name
}

output "cloudwatch_log_group_arn" {
  description = "Arn of cloudwatch log group created"
  value       = aws_cloudwatch_log_group.cluster.arn
}