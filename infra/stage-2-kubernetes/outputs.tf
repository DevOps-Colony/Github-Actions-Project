# outputs.tf - Outputs for Stage 2

output "namespace_name" {
  description = "Name of the created Kubernetes namespace"
  value       = kubernetes_namespace.app_namespace.metadata[0].name
}

output "db_secret_name" {
  description = "Name of the database secret in Kubernetes"
  value       = kubernetes_secret.db_secret.metadata[0].name
}

output "aws_load_balancer_controller_role_arn" {
  description = "ARN of the AWS Load Balancer Controller IAM role"
  value       = aws_iam_role.aws_load_balancer_controller.arn
}

output "cluster_info" {
  description = "EKS cluster information"
  value = {
    cluster_name     = data.terraform_remote_state.stage_1.outputs.eks_cluster_id
    cluster_endpoint = data.terraform_remote_state.stage_1.outputs.eks_cluster_endpoint
    namespace        = kubernetes_namespace.app_namespace.metadata[0].name
  }
}

output "application_ready" {
  description = "Indicates that the Kubernetes infrastructure is ready for application deployment"
  value       = true
}

output "next_steps" {
  description = "Information about what to do next"
  value = {
    namespace_created                    = kubernetes_namespace.app_namespace.metadata[0].name
    database_secret_created             = kubernetes_secret.db_secret.metadata[0].name
    aws_load_balancer_controller_ready  = "Use ingress annotations to create ALB"
    metrics_server_ready                = "HPA can be configured for application pods"
    ready_for_application_deployment    = true
  }
}