provider "aws" {
  region = var.aws_region
}

module "s3_backend" {
  source          = "./modules/s3-backend"
  bucket_name     = var.s3_backend_bucket
  dynamodb_table  = var.s3_dynamodb_table
}

module "vpc" {
  source = "./modules/vpc"
  ...
}

module "eks" {
  source = "./modules/eks"
  ...
}

module "alb" {
  source = "./modules/alb"
  ...
}

module "alb_controller" {
  source = "./modules/alb-controller"
  ...
}
