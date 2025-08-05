variable "aws_region" {
  description = "AWS region for the backend bucket"
  type        = string
  default     = "ap-south-1"
}

variable "force_destroy" {
  description = "Whether to force destroy the S3 bucket"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags for resources"
  type        = map(string)
  default     = {}
}
