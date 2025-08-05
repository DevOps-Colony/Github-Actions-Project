variable "bucket_name" {
  type        = string
  description = "The name of the S3 bucket for Terraform backend state"
}

variable "dynamodb_table" {
  type        = string
  description = "The name of the DynamoDB table for Terraform state locking"
}

variable "force_destroy" {
  type        = bool
  description = "Boolean that indicates all objects should be deleted from the bucket so that the bucket can be destroyed without error"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the resources"
}
