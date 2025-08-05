variable "project_name" {
  description = "Project name prefix for the S3 bucket and DynamoDB table"
  type        = string
}

variable "aws_region" {
  description = "AWS region to deploy the backend resources"
  type        = string
}

variable "force_destroy" {
  description = "Whether to force destroy the S3 bucket (delete all objects)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
