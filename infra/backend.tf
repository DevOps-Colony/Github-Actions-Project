terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "github-actions-project/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.4.0"
}
