project_name         = "github-actions-project"
environment          = "staging"
aws_region           = "ap-south-1"

vpc_cidr_block       = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]

cluster_name         = "github-actions-cluster"
cluster_version      = "1.27"
node_group_name      = "github-actions-nodes"
instance_types       = ["t3.medium"]
desired_capacity     = 2
min_size             = 1
max_size             = 3

alb_name             = "github-actions-alb"

tags = {
  Owner       = "DevOps Team"
  Environment = "staging"
  Project     = "github-actions-project"
}
