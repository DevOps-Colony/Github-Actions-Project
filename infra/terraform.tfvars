aws_region               = "us-west-2"
name_prefix              = "python-project"
environment              = "staging"

s3_backend_bucket        = "python-project-terraform-state"
s3_dynamodb_table        = "python-project-terraform-locks"

vpc_cidr                 = "10.0.0.0/16"
public_subnet_cidrs      = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs     = ["10.0.101.0/24", "10.0.102.0/24"]

eks_cluster_role_arn     = "arn:aws:iam::123456789012:role/EKSClusterRole"
eks_node_role_arn        = "arn:aws:iam::123456789012:role/EKSNodeRole"

alb_sg_id                = "sg-0123456789abcdef0"
alb_service_account_name = "aws-load-balancer-controller"
