variable "vpc_name" {
  description = "Name to be used on all the resources as identifier"
  type        = string
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "A list of availability zones names or ids in the region"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "A list of private subnet CIDR blocks"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "A list of public subnet CIDR blocks"
  type        = list(string)
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}