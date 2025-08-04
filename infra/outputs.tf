output "cluster_name" {
  value = var.cluster_name
}

output "region" {
  value = var.aws_region
}

output "alb_dns" {
  value = module.alb.lb_dns_name
}

output "alb_dns_name" {
  description = "DNS of the load balancer"
  value       = aws_lb.this.dns_name
}
