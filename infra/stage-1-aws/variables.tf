variable "aws_region" {
  default = "ap-south-1"
}

variable "environment" {
  default = "staging"
}

variable "project_name" {
  default = "bankapp"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  type    = list(string)
  default = ["ap-south-1a", "ap-south-1b"]
}

variable "private_subnet_cidrs" {
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "public_subnet_cidrs" {
  default = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "eks_cluster_version" {
  default = "1.28"
}

variable "eks_node_desired_capacity" {
  default = 2
}

variable "eks_node_max_capacity" {
  default = 3
}

variable "eks_node_min_capacity" {
  default = 1
}

variable "eks_node_instance_types" {
  default = ["t3.small"]
}

variable "rds_instance_class" {
  default = "db.t3.micro"
}

variable "db_name" {
  default = "bankdb"
}

variable "db_username" {
  default = "admin"
}

variable "db_password" {
  default = "changeMe123!"
}
