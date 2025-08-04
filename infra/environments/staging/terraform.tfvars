aws_region           = "ap-south-1"
project              = "github-actions-project"
environment          = "staging"

s3_backend_bucket    = "github-actions-project-tfstate"
s3_dynamodb_table    = "github-actions-project-locks"

vpc_cidr             = "10.0.0.0/16"
public_subnets       = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnets      = ["10.0.3.0/24", "10.0.4.0/24"]

cluster_name         = "github-actions-cluster-staging"
cluster_version      = "1.29"
node_instance_type   = "t3.medium"
desired_capacity     = 2
max_capacity         = 3
min_capacity         = 1
