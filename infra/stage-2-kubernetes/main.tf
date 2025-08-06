# main.tf - Kubernetes resources for Stage 2

# Create namespace
resource "kubernetes_namespace" "app_namespace" {
  metadata {
    name = var.namespace
    labels = {
      name        = var.namespace
      project     = var.project_name
      environment = var.environment
    }
  }
}

# Create database secret
resource "kubernetes_secret" "db_secret" {
  metadata {
    name      = "db-secret"
    namespace = kubernetes_namespace.app_namespace.metadata[0].name
  }

  data = {
    username = data.terraform_remote_state.stage_1.outputs.stage_2_inputs.rds_username
    password = var.db_password
    database = data.terraform_remote_state.stage_1.outputs.stage_2_inputs.rds_database_name
    host     = data.terraform_remote_state.stage_1.outputs.rds_endpoint
    port     = data.terraform_remote_state.stage_1.outputs.rds_port
  }

  type = "Opaque"
}

# Service Account for AWS Load Balancer Controller
resource "kubernetes_service_account" "aws_load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.aws_load_balancer_controller.arn
    }
    labels = {
      "app.kubernetes.io/component" = "controller"
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
    }
  }
}

# IAM Role for AWS Load Balancer Controller
resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "${var.project_name}-${var.environment}-aws-load-balancer-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.terraform_remote_state.stage_1.outputs.eks_oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(data.terraform_remote_state.stage_1.outputs.eks_oidc_provider_arn, "/^.*oidc-provider//", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
            "${replace(data.terraform_remote_state.stage_1.outputs.eks_oidc_provider_arn, "/^.*oidc-provider//", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

# Attach the AWS Load Balancer Controller policy to the role
resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/AWSLoadBalancerControllerIAMPolicy"
  role       = aws_iam_role.aws_load_balancer_controller.name
}

# Install AWS Load Balancer Controller via Helm
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.6.2"

  values = [
    yamlencode({
      clusterName = data.terraform_remote_state.stage_1.outputs.eks_cluster_id
      serviceAccount = {
        create = false
        name   = kubernetes_service_account.aws_load_balancer_controller.metadata[0].name
      }
      region = var.aws_region
      vpcId  = data.terraform_remote_state.stage_1.outputs.vpc_id
    })
  ]

  depends_on = [
    kubernetes_service_account.aws_load_balancer_controller,
    aws_iam_role_policy_attachment.aws_load_balancer_controller
  ]
}

# Install Metrics Server for HPA
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.11.0"

  values = [
    yamlencode({
      args = [
        "--cert-dir=/tmp",
        "--secure-port=4443",
        "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname",
        "--kubelet-use-node-status-port",
        "--metric-resolution=15s"
      ]
    })
  ]
}

# Create a config map with cluster information
resource "kubernetes_config_map" "cluster_info" {
  metadata {
    name      = "cluster-info"
    namespace = kubernetes_namespace.app_namespace.metadata[0].name
  }

  data = {
    cluster_name     = data.terraform_remote_state.stage_1.outputs.eks_cluster_id
    cluster_endpoint = data.terraform_remote_state.stage_1.outputs.eks_cluster_endpoint
    aws_region       = var.aws_region
    environment      = var.environment
    project_name     = var.project_name
  }
}