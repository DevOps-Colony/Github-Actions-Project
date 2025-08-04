variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "github-actions-project"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "staging"
}

variable "s3_backend_bucket" {
  description = "Name of the S3 bucket for Terraform state"
  type        = string
  default     = "github-actions-project-tfstate"
}

variable "s3_dynamodb_table" {
  description = "Name of the DynamoDB table for state locking"
  type        = string
  default     = "github-actions-project-locks"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "List of public subnet CIDRs"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  description = "List of private subnet CIDRs"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "github-actions-cluster-staging"
}

variable "cluster_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS nodes"
  type        = string
  default     = "t3.medium"
}

variable "desired_capacity" {
  type    = number
  default = 2
}

variable "max_capacity" {
  type    = number
  default = 3
}

variable "min_capacity" {
  type    = number
  default = 1
}
