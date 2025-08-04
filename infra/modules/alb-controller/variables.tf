variable "cluster_name" {
  type = string
}

variable "region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "service_account_name" {
  type = string
}

variable "depends_on" {
  description = "List of dependencies (e.g., IAM roles)"
  type        = list(any)
}
