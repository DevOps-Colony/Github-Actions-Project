variable "aws_region" {
  type        = string
  description = "AWS region to deploy resources in"
}

variable "project_name" {
  type        = string
  description = "Name of the project"
}

variable "environment" {
  type        = string
  description = "Deployment environment name"
}

variable "vpc_cidr_block" {
  type        = string
  description = "CIDR block for the VPC"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks for public subnets"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks for private subnets"
}

variable "cluster_name" {
  type        = string
  description = "EKS Cluster name"
}

variable "cluster_version" {
  type        = string
  description = "EKS Cluster version"
}

variable "node_group_name" {
  type        = string
  description = "EKS node group name"
}

variable "instance_types" {
  type        = list(string)
  description = "List of EC2 instance types for the EKS worker nodes"
}

variable "desired_capacity" {
  type        = number
  description = "Desired number of worker nodes"
}

variable "min_size" {
  type        = number
  description = "Minimum number of worker nodes"
}

variable "max_size" {
  type        = number
  description = "Maximum number of worker nodes"
}

variable "alb_name" {
  type        = string
  description = "Name of the Application Load Balancer"
}

variable "tags" {
  type        = map(string)
  description = "Common tags for all resources"
}

# Backend variables (only declared once here)
variable "bucket_name" {
  type        = string
  description = "The name of the S3 bucket for Terraform backend state"
}

variable "dynamodb_table" {
  type        = string
  description = "The name of the DynamoDB table for Terraform state locking"
}
