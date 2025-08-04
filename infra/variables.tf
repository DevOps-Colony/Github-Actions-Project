variable "aws_region" {
  type    = string
  default = "us-west-2"
}

variable "name_prefix" {
  type = string
}

variable "environment" {
  type = string
}

# S3 backend
variable "s3_backend_bucket" {
  type = string
}

variable "s3_dynamodb_table" {
  type = string
}

# VPC
variable "vpc_cidr" {
  type = string
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

# IAM
variable "eks_cluster_role_arn" {
  type = string
}

variable "eks_node_role_arn" {
  type = string
}

variable "alb_sg_id" {
  type = string
}

variable "alb_service_account_name" {
  type = string
}
