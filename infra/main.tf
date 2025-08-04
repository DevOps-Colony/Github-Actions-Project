terraform {
  required_version = ">= 1.4.0"

  backend "s3" {
    bucket         = "python-project-terraform-state"
    key            = "staging/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "python-project-terraform-locks"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority)
    token                  = data.aws_eks_cluster_auth.token.token
  }
}

data "aws_eks_cluster_auth" "token" {
  name = module.eks.cluster_name
}

module "s3_backend" {
  source         = "./modules/s3-backend"
  bucket_name    = var.s3_backend_bucket
  dynamodb_table = var.s3_dynamodb_table
}

module "vpc" {
  source              = "./modules/vpc"
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  name_prefix         = var.name_prefix
}

module "eks" {
  source           = "./modules/eks"
  cluster_name     = "${var.name_prefix}-cluster-${var.environment}"
  cluster_role_arn = var.eks_cluster_role_arn
  node_role_arn    = var.eks_node_role_arn
  subnet_ids       = module.vpc.private_subnet_ids
  name_prefix      = var.name_prefix
}

module "alb" {
  source              = "./modules/alb"
  name_prefix         = var.name_prefix
  subnet_ids          = module.vpc.public_subnet_ids
  vpc_id              = module.vpc.vpc_id
  lb_security_group_id = var.alb_sg_id
}

module "alb_controller" {
  source               = "./modules/alb-controller"
  cluster_name         = module.eks.cluster_name
  region               = var.aws_region
  vpc_id               = module.vpc.vpc_id
  service_account_name = var.alb_service_account_name
  depends_on           = [module.eks]
}
