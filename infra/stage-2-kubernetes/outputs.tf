output "namespace" {
  description = "Application namespace"
  value       = kubernetes_namespace.app.metadata[0].name
}

output "db_secret_name" {
  description = "Name of the database secret"
  value       = kubernetes_secret.db_secret.metadata[0].name
}

output "aws_load_balancer_controller_status" {
  description = "Status of AWS Load Balancer Controller"
  value       = helm_release.aws_load_balancer_controller.status
}

output "cluster_info" {
  description = "EKS cluster information"
  value = {
    cluster_name = data.terraform_remote_state.aws_infra.outputs.eks_cluster_id
    endpoint     = data.aws_eks_cluster.cluster.endpoint
    version      = data.aws_eks_cluster.cluster.version
  }
}
