output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "eks_cluster_id" {
  value = module.eks.cluster_id
}

output "eks_cluster_arn" {
  value = module.eks.cluster_arn
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_cluster_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}

output "eks_cluster_security_group_id" {
  value = module.eks.cluster_security_group_id
}

output "eks_node_security_group_id" {
  value = module.eks.node_security_group_id
}

output "eks_oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app_repo.repository_url
}

output "load_balancer_dns" {
  value = aws_lb.app_alb.dns_name
}

output "load_balancer_arn" {
  value = aws_lb.app_alb.arn
}

output "target_group_arn" {
  value = aws_lb_target_group.app_tg.arn
}

output "rds_endpoint" {
  value = module.rds.endpoint
}

output "rds_port" {
  value = module.rds.port
}

output "application_url" {
  value = "http://${aws_lb.app_alb.dns_name}"
}

output "stage_2_inputs" {
  value = {
    cluster_name                    = module.eks.cluster_id
    cluster_endpoint                = module.eks.cluster_endpoint
    cluster_certificate_authority   = module.eks.cluster_certificate_authority_data
    oidc_provider_arn               = module.eks.oidc_provider_arn
    target_group_arn                = aws_lb_target_group.app_tg.arn
    rds_endpoint                    = module.rds.endpoint
    rds_database_name               = var.db_name
    rds_username                    = var.db_username
  }
}
