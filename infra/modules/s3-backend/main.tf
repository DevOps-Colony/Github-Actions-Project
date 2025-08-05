terraform {
  required_version = ">= 1.4.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 bucket for Terraform state
resource "aws_s3_bucket" "tf_backend" {
  bucket        = "tfstate-${random_id.bucket_suffix.hex}"
  force_destroy = var.force_destroy

  tags = merge(var.tags, {
    Name = "tfstate-${random_id.bucket_suffix.hex}"
  })
}

# DynamoDB table for state locking
resource "aws_dynamodb_table" "tf_locks" {
  name         = "tf-locks-${random_id.bucket_suffix.hex}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = merge(var.tags, {
    Name = "tf-locks-${random_id.bucket_suffix.hex}"
  })
}

output "bucket_name" {
  value = aws_s3_bucket.tf_backend.bucket
}

output "dynamodb_table" {
  value = aws_dynamodb_table.tf_locks.name
}
