terraform {
  required_version = ">= 1.4.0"

  backend "s3" {
    bucket         = "github-actions-project-tfstate"
    key            = "staging/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "github-actions-project-locks"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

# Create S3 backend and DynamoDB lock table
module "s3_backend" {
  source              = "../modules/s3-backend"
  project_name        = var.project_name
  environment         = var.environment
  region              = var.aws_region
  force_destroy       = true
}

# VPC
module "vpc" {
  source        = "../modules/vpc"
  project_name  = var.project_name
  environment   = var.environment
  region        = var.aws_region
}

# IAM Roles
module "iam" {
  source              = "../modules/iam"
  cluster_name        = var.cluster_name
  region              = var.aws_region
  service_account_ns  = "kube-system"
  service_account_name = "aws-load-balancer-controller"
}

# EKS Cluster
module "eks" {
  source           = "../modules/eks"
  cluster_name     = var.cluster_name
  region           = var.aws_region
  subnet_ids       = module.vpc.private_subnet_ids
  vpc_id           = module.vpc.vpc_id
  node_group_name  = "staging-node-group"
  node_instance_type = "t3.medium"
  desired_capacity = 2
  max_capacity     = 3
  min_capacity     = 1
}

# ALB
module "alb" {
  source        = "../modules/alb"
  vpc_id        = module.vpc.vpc_id
  subnet_ids    = module.vpc.public_subnet_ids
  project_name  = var.project_name
  environment   = var.environment
}

# ALB Controller via Helm
module "alb_controller" {
  source               = "../modules/alb-controller"
  cluster_name         = var.cluster_name
  region               = var.aws_region
  vpc_id               = module.vpc.vpc_id
  service_account_name = module.iam.lb_controller_service_account_name
}
