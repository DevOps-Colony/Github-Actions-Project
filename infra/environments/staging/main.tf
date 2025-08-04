terraform {
  required_version = ">= 1.4.0"
}

provider "aws" {
  region = var.aws_region
}

module "s3_backend" {
  source     = "./modules/s3-backend"
  bucket     = var.s3_backend_bucket
  table_name = var.s3_backend_dynamodb_table
  region     = var.aws_region
}
