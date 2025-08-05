project_name    = "bankapp"
environment     = "production"
aws_region      = "us-west-2"

# VPC Configuration
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["us-west-2a", "us-west-2b", "us-west-2c"]
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

# EKS Configuration (Production-ready)
eks_cluster_version      = "1.28"
eks_node_desired_capacity = 3
eks_node_max_capacity    = 6
eks_node_min_capacity    = 2
eks_node_instance_types  = ["t3.medium"]

# RDS Configuration
rds_instance_class = "db.t3.small"
db_name           = "bankapp"
db_username       = "admin"
db_password       = "bankapp123!"  # Use AWS Secrets Manager in production