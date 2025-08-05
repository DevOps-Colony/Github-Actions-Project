project_name    = "bankapp"
environment     = "staging"
aws_region      = "us-west-2"

# VPC Configuration
vpc_cidr             = "10.1.0.0/16"
availability_zones   = ["us-west-2a", "us-west-2b"]
private_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24"]
public_subnet_cidrs  = ["10.1.101.0/24", "10.1.102.0/24"]

# EKS Configuration (Cost-optimized for staging)
eks_cluster_version      = "1.28"
eks_node_desired_capacity = 1
eks_node_max_capacity    = 2
eks_node_min_capacity    = 1
eks_node_instance_types  = ["t3.small"]

# RDS Configuration
rds_instance_class = "db.t3.micro"
db_name           = "bankapp"
db_username       = "admin"  
db_password       = "bankapp123!"