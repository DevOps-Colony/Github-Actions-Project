variable "bucket_name" {
  type        = string
  description = "The name of the S3 bucket for Terraform state"
}

variable "dynamodb_table" {
  type        = string
  description = "The name of the DynamoDB table for state locking"
}

variable "force_destroy" {
  type        = bool
  description = "Whether to force destroy the bucket"
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default     = {}
}
