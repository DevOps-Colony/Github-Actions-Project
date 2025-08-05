terraform {
  required_version = ">= 1.4.0"

  backend "s3" {
    bucket         = "github-actions-project-tfstate"   # Will be created automatically by s3-backend module
    key            = "staging/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "github-actions-project-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

# --- VPC Module ---
module "vpc" {
  source = "../../modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  cidr_block           = var.vpc_cidr_block
  azs                  = data.aws_availability_zones.available.names
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

# --- EKS Module ---
module "eks" {
  source = "../../modules/eks"

  cluster_name     = var.cluster_name
  cluster_version  = var.cluster_version
  vpc_id           = module.vpc.vpc_id
  subnet_ids       = module.vpc.private_subnet_ids
  node_group_name  = var.node_group_name
  instance_types   = var.instance_types
  desired_capacity = var.desired_capacity
  min_size         = var.min_size
  max_size         = var.max_size
  tags             = var.tags
}

# --- ALB Module ---
module "alb" {
  source = "../../modules/alb"

  name            = var.alb_name
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.public_subnet_ids
  internal        = false
  security_groups = [module.eks.node_security_group_id]
  tags            = var.tags
}

# --- ALB Controller Module ---
module "alb_controller" {
  source = "../../modules/alb-controller"

  cluster_name         = var.cluster_name
  region               = var.aws_region
  vpc_id               = module.vpc.vpc_id
  service_account_name = "aws-load-balancer-controller-sa"
}

# --- S3 Backend Auto-Creation Module ---
module "s3_backend" {
  source = "../../modules/s3-backend"

  project_name   = var.project_name
  aws_region     = var.aws_region
  force_destroy  = true

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# --- Outputs ---
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_cluster_certificate_authority" {
  value = module.eks.cluster_certificate_authority
}

output "alb_dns_name" {
  value = module.alb.dns_name
}

# Pass bucket & table to pipeline
output "bucket_name" {
  value = module.s3_backend.bucket_name
}

output "dynamodb_table" {
  value = module.s3_backend.dynamodb_table
}
