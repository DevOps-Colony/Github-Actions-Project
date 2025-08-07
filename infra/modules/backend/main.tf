variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (staging/production)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

locals {
  state_bucket = "${var.project_name}-terraform-state-${var.environment}"
  lock_table   = "${var.project_name}-terraform-locks-${var.environment}"
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = local.state_bucket

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform_locks" {
  name           = local.lock_table
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = local.lock_table
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

output "state_bucket" {
  value = aws_s3_bucket.terraform_state.bucket
}

output "dynamodb_table" {
  value = aws_dynamodb_table.terraform_locks.name
}
