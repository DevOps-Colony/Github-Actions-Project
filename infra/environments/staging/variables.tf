variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR block for VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDRs for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDRs for private subnets"
  type        = list(string)
}

variable "cluster_name" {
  description = "EKS Cluster name"
  type        = string
}

variable "cluster_version" {
  description = "EKS Cluster version"
  type        = string
}

variable "node_group_name" {
  description = "EKS Node group name"
  type        = string
}

variable "instance_types" {
  description = "EC2 instance types for nodes"
  type        = list(string)
}

variable "desired_capacity" {
  description = "Desired node count"
  type        = number
}

variable "min_size" {
  description = "Minimum node count"
  type        = number
}

variable "max_size" {
  description = "Maximum node count"
  type        = number
}

variable "alb_name" {
  description = "Application Load Balancer name"
  type        = string
}

variable "tags" {
  description = "Tags for all resources"
  type        = map(string)
  default     = {}
}
