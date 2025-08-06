# data.tf - Data sources to get Stage 1 outputs

# Get the remote state from Stage 1
data "terraform_remote_state" "stage_1" {
  backend = "s3"
  config = {
    bucket = "bankapp-terraform-state-2024"
    key    = "stage-1-${var.environment}/terraform.tfstate"
    region = var.aws_region
  }
}

# Get EKS cluster information
data "aws_eks_cluster" "main" {
  name = data.terraform_remote_state.stage_1.outputs.eks_cluster_id
}

data "aws_eks_cluster_auth" "main" {
  name = data.terraform_remote_state.stage_1.outputs.eks_cluster_id
}

# Get caller identity for AWS account ID
data "aws_caller_identity" "current" {}

# Get availability zones
data "aws_availability_zones" "available" {
  state = "available"
}