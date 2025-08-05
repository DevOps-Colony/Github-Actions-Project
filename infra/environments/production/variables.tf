# infra/environments/production/variables.tf

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "bankapp"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b", "us-west-2c"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

# EKS Configuration (Production-ready)
variable "eks_cluster_version" {
  description = "EKS cluster version"
  type        = string
  default     = "1.28"
}

variable "eks_node_desired_capacity" {
  description = "Desired number of nodes"
  type        = number
  default     = 3
}

variable "eks_node_max_capacity" {
  description = "Maximum number of nodes"
  type        = number
  default     = 6
}

variable "eks_node_min_capacity" {
  description = "Minimum number of nodes"
  type        = number
  default     = 2
}

variable "eks_node_instance_types" {
  description = "Instance types for EKS nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

# RDS Configuration (Production-ready)
variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.small"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "bankapp"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Database password (should use AWS Secrets Manager in production)"
  type        = string
  default     = "bankapp123!"
  sensitive   = true
}

# SSL Configuration
variable "ssl_certificate_arn" {
  description = "ARN of the SSL certificate for HTTPS listener"
  type        = string
  default     = null
  # You can create a certificate using:
  # aws acm request-certificate --domain-name your-domain.com --validation-method DNS
}

variable "domain_name" {
  description = "Domain name for the application (optional)"
  type        = string
  default     = null
}

# Helm Configuration
variable "helm_chart_name" {
  description = "Name of the Helm chart for the application"
  type        = string
  default     = "bankapp"
}

variable "helm_chart_version" {
  description = "Version of the Helm chart"
  type        = string
  default     = "1.0.0"
}

variable "helm_namespace" {
  description = "Kubernetes namespace for Helm deployment"
  type        = string
  default     = "production"
}

variable "app_image_tag" {
  description = "Docker image tag for the application"
  type        = string
  default     = "latest"
}

variable "app_replicas" {
  description = "Number of application replicas"
  type        = number
  default     = 3
}

variable "app_cpu_request" {
  description = "CPU request for application pods"
  type        = string
  default     = "100m"
}

variable "app_memory_request" {
  description = "Memory request for application pods"
  type        = string
  default     = "256Mi"
}

variable "app_cpu_limit" {
  description = "CPU limit for application pods"
  type        = string
  default     = "500m"
}

variable "app_memory_limit" {
  description = "Memory limit for application pods"
  type        = string
  default     = "512Mi"
}
