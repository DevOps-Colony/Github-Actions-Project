terraform {
  required_version = ">= 1.4.0"

  backend "s3" {
    bucket         = "github-actions-project-tfstate"   # Auto-created by module below
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

# --- S3 Backend Auto-Creation ---
module "s3_backend" {
  source      = "../../modules/s3-backend"
  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region
  force_destroy = true
  tags         = var.tags
}

# --- VPC ---
module "vpc" {
  source = "../../modules/vpc"
  project_name         = var.project_name
  environment          = var.environment
  cidr_block           = var.vpc_cidr_block
  azs                  = data.aws_availability_zones.available.names
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

# --- EKS ---
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

# --- ALB ---
module "alb" {
  source = "../../modules/alb"
  name            = var.alb_name
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.public_subnet_ids
  internal        = false
  security_groups = [module.eks.node_security_group_id]
  tags            = var.tags
}

# --- ALB Controller ---
module "alb_controller" {
  source = "../../modules/alb-controller"
  cluster_name         = var.cluster_name
  region               = var.aws_region
  vpc_id               = module.vpc.vpc_id
  service_account_name = "aws-load-balancer-controller-sa"
}

# --- Outputs ---
output "bucket_name" {
  value = module.s3_backend.bucket_name
}

output "dynamodb_table" {
  value = module.s3_backend.dynamodb_table
}
