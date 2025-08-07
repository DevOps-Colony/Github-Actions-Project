# infra/environments/production/main.tf

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10"
    }
  }
  
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "terraform"
    }
  }
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"
  
  vpc_name             = "${var.project_name}-${var.environment}"
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  environment         = var.environment
  
  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# EKS Module
module "eks" {
  source = "../../modules/eks"
  
  cluster_name    = "${var.project_name}-${var.environment}"
  cluster_version = var.eks_cluster_version
  
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids
  
  node_groups = {
    main = {
      desired_capacity = var.eks_node_desired_capacity
      max_capacity     = var.eks_node_max_capacity
      min_capacity     = var.eks_node_min_capacity
      instance_types   = var.eks_node_instance_types
      capacity_type    = "ON_DEMAND"   # Use ON_DEMAND for production reliability
      
      k8s_labels = {
        Environment = var.environment
        NodeGroup   = "main"
      }
    }
  }
  
  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# RDS Module - Production Configuration
module "rds" {
  source = "../../modules/rds"
  
  identifier = "${var.project_name}-${var.environment}-db"
  
  # Module required fields
  environment  = var.environment
  project_name = var.project_name

  # Engine configuration
  engine         = "mysql"
  engine_version = "8.0.35"
  instance_class = var.rds_instance_class
  
  # Database configuration
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  
  # Network configuration
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnet_ids
  allowed_security_group_ids  = [module.eks.cluster_security_group_id]
  publicly_accessible      = false
  
  # Storage configuration (larger for production)
  allocated_storage     = 100
  max_allocated_storage = 1000
  storage_type         = "gp3"
  storage_encrypted    = true
  
  # Backup configuration (robust for production)
  backup_retention_period = 14
  backup_window          = "07:00-09:00"
  maintenance_window     = "Sun:09:00-Sun:11:00"
  copy_tags_to_snapshot  = true
  
  # High availability (enabled for production)
  multi_az = true
  
  # Monitoring (comprehensive for production)
  monitoring_interval                    = 60
  performance_insights_enabled           = true
  performance_insights_retention_period  = 7
  
  # Logging (comprehensive for production)
  enabled_cloudwatch_logs_exports = ["error", "general", "slow_query"]
  cloudwatch_log_group_retention_in_days = 30
  
  # Deletion protection (enabled for production)
  deletion_protection = true
  skip_final_snapshot = false
  
  # Create secrets manager secret for production
  create_secrets_manager_secret = true
  secrets_manager_recovery_window_in_days = 7
  
  # Create read replica for production
  create_read_replica = true
  read_replica_instance_class = "db.t3.small"
  
  # Enhanced parameter configuration for production
  parameters = [
    {
      name  = "innodb_buffer_pool_size"
      value = "{DBInstanceClassMemory*3/4}"
    },
    {
      name  = "max_connections"
      value = "2000"
    },
    {
      name  = "slow_query_log"
      value = "1"
    },
    {
      name  = "long_query_time"
      value = "1"
    },
    {
      name  = "general_log"
      value = "1"
    },
    {
      name  = "innodb_log_file_size"
      value = "268435456"  # 256MB
    },
    {
      name  = "query_cache_type"
      value = "1"
    },
    {
      name  = "query_cache_size"
      value = "67108864"  # 64MB
    }
  ]
  
  tags = {
    Environment = var.environment
    Project     = var.project_name
    Backup      = "required"
    Monitoring  = "enabled"
  }
}

# ECR Repository (shared across environments)
data "aws_ecr_repository" "app_repo" {
  name = var.project_name
}

# Application Load Balancer
resource "aws_lb" "app_alb" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets           = module.vpc.public_subnet_ids

  enable_deletion_protection = true  # Enable for production

  # Access logs for production
  access_logs {
    bucket  = aws_s3_bucket.alb_logs.bucket
    prefix  = "alb-logs"
    enabled = true
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# S3 bucket for ALB access logs
resource "aws_s3_bucket" "alb_logs" {
  bucket        = "${var.project_name}-${var.environment}-alb-logs-${random_id.bucket_suffix.hex}"
  force_destroy = false  # Protect logs in production

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id     = "log_lifecycle"
    status = "Enabled"

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# Security Group for ALB
resource "aws_security_group" "alb_sg" {
  name_prefix = "${var.project_name}-${var.environment}-alb-"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-alb-sg"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Target Group for ALB
resource "aws_lb_target_group" "app_tg" {
  name        = "${var.project_name}-${var.environment}-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 15    # More frequent health checks for production
    matcher             = "200"
    path                = "/actuator/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  # Stickiness for production (if needed)
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = false
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# ALB Listener (with HTTPS support for production)
resource "aws_lb_listener" "app_listener_http" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "80"
  protocol          = "HTTP"

  # Redirect HTTP to HTTPS in production
  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS Listener (requires SSL certificate)
resource "aws_lb_listener" "app_listener_https" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.ssl_certificate_arn  # You'll need to create this

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# Get EKS cluster data for Kubernetes provider
data "aws_eks_cluster" "cluster" {
  depends_on = [module.eks]
  name       = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  depends_on = [module.eks]
  name       = module.eks.cluster_id
}

# Kubernetes provider
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.cluster.name]
  }
}

# Kubernetes Secret for Database
resource "kubernetes_secret" "db_secret" {
  depends_on = [module.eks, module.rds]
  
  metadata {
    name      = "db-secret"
    namespace = "production"
  }

  data = {
    username = module.rds.db_instance_username
    password = module.rds.db_instance_password
    host     = module.rds.db_instance_endpoint
    database = module.rds.db_instance_name
    port     = tostring(module.rds.db_instance_port)
    jdbc_url = module.rds.jdbc_url
  }

  type = "Opaque"
}

# Create production namespace
resource "kubernetes_namespace" "production" {
  depends_on = [module.eks]
  
  metadata {
    name = "production"
    
    labels = {
      environment = "production"
      project     = var.project_name
    }
  }
}

# CloudWatch Log Group for Application Logs
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/eks/${module.eks.cluster_id}/application"
  retention_in_days = 30

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}