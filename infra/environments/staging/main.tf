terraform {
  required_version = ">= 1.4.0"

  backend "s3" {
    bucket         = "github-actions-project-tfstate"
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

module "vpc" {
  source = "../../modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  cidr_block           = var.vpc_cidr_block
  azs                  = data.aws_availability_zones.available.names
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

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

module "alb" {
  source = "../../modules/alb"

  name            = var.alb_name
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.public_subnet_ids
  internal        = false
  security_groups = [module.eks.node_security_group_id]
  tags            = var.tags
}

module "alb_controller" {
  source = "../../modules/alb-controller"

  cluster_name         = var.cluster_name
  region               = var.aws_region
  vpc_id               = module.vpc.vpc_id
  service_account_name = "aws-load-balancer-controller-sa"
}

module "s3_backend" {
  source = "../../modules/s3-backend"

  bucket_name    = "github-actions-project-tfstate"
  dynamodb_table = "github-actions-project-locks"
  force_destroy  = true

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}
