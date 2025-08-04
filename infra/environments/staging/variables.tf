variable "aws_region" {
  default = "ap-south-1"
}

variable "s3_backend_bucket" {
  default = "terraform-backend-github-actions"
}

variable "s3_backend_dynamodb_table" {
  default = "terraform-locks-github-actions"
}
