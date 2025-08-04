terraform {
  required_version = ">= 1.4.0"
  backend "s3" {
    bucket         = "terraform-backend-github-actions"
    key            = "staging/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks-github-actions"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

module "s3_backend" {
  source     = "../../modules/s3-backend"
  bucket     = "terraform-backend-github-actions"
  table_name = "terraform-locks-github-actions"
  region     = var.aws_region
}
