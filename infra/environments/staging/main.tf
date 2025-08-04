terraform {
  required_version = ">= 1.4.0"

  backend "s3" {
    bucket         = "github-actions-project-tfstate"
    key            = "staging/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "github-actions-project-locks"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {}

module "s3_backend" {
  source         = "../../modules/s3-backend"
  bucket_name    = var.s3_backend_bucket
  dynamodb_table = var.s3_dynamodb_table
}

module "vpc" {
  source               = "../../modules/vpc"
  vpc_cidr             = var.vpc_cidr
  public_subnets       = var.public_subnets
  private_subnets      = var.private_subnets
  availability_zones   = data.aws_availability_zones.available.names
  environment          = var.environment
  project              = var.project
}

module "eks" {
  source               = "../../modules/eks"
  cluster_name         = var.cluster_name
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  public_subnet_ids    = module.vpc.public_subnet_ids
  cluster_version      = var.cluster_version
  environment          = var.environment
  project              = var.project
  node_instance_type   = var.node_instance_type
  desired_capacity     = var.desired_capacity
  max_capacity         = var.max_capacity
  min_capacity         = var.min_capacity
}

module "alb" {
  source             = "../../modules/alb"
  name               = var.project
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  target_port        = 80
  environment        = var.environment
  project            = var.project
}

module "alb_controller" {
  source                  = "../../modules/alb-controller"
  cluster_name            = module.eks.cluster_name
  oidc_provider_arn       = module.eks.oidc_provider_arn
  service_account_name    = "aws-load-balancer-controller"
  namespace               = "kube-system"
  vpc_id                  = module.vpc.vpc_id
  region                  = var.aws_region
}
