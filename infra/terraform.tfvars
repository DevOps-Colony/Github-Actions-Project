project_name    = "bankapp"
environment     = "dev"
# aws_region is now set via TF_VAR_aws_region environment variable

# IMPORTANT: Make this unique by adding your initials or random numbers
terraform_state_bucket = "bankapp-terraform-state-devops-colony-2024"

# VPC Configuration
vpc_cidr             = "10.0.0.0/16"
# availability_zones are now fetched automatically based on the AWS region
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

# EKS Configuration
eks_cluster_version      = "1.28"
eks_node_desired_capacity = 2
eks_node_max_capacity    = 4
eks_node_min_capacity    = 1
eks_node_instance_types  = ["t3.medium"]

# RDS Configuration
rds_instance_class = "db.t3.micro"
db_name           = "bankapp"
db_username       = "admin"
db_password       = "bankapp123!"