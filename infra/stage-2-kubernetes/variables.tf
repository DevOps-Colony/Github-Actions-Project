variable "aws_region" {
  description = "AWS region for the infrastructure"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for application"
  type        = string
}

variable "db_password" {
  description = "Database password (used for Kubernetes secret)"
  type        = string
  sensitive   = true
}
