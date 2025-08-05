# infra/modules/rds/outputs.tf

# Database Instance Information
output "db_instance_id" {
  description = "The RDS instance ID"
  value       = aws_db_instance.main.id
}

output "db_instance_identifier" {
  description = "The RDS instance identifier"
  value       = aws_db_instance.main.identifier
}

output "db_instance_arn" {
  description = "The ARN of the RDS instance"
  value       = aws_db_instance.main.arn
}

output "db_instance_resource_id" {
  description = "The RDS Resource ID of this instance"
  value       = aws_db_instance.main.resource_id
}

# Connection Information
output "db_instance_endpoint" {
  description = "The RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
}

output "db_instance_address" {
  description = "The RDS instance hostname"
  value       = aws_db_instance.main.address
}

output "db_instance_port" {
  description = "The RDS instance port"
  value       = aws_db_instance.main.port
}

# Database Information
output "db_instance_name" {
  description = "The database name"
  value       = aws_db_instance.main.db_name
}

output "db_instance_username" {
  description = "The master username for the database"
  value       = aws_db_instance.main.username
  sensitive   = true
}

output "db_instance_password" {
  description = "The database password (this password may be old, because Terraform doesn't track it after initial creation)"
  value       = var.password != null ? var.password : (length(random_password.db_password) > 0 ? random_password.db_password[0].result : null)
  sensitive   = true
}

# Engine Information
output "db_instance_engine" {
  description = "The database engine"
  value       = aws_db_instance.main.engine
}

output "db_instance_engine_version" {
  description = "The running version of the database"
  value       = aws_db_instance.main.engine_version_actual
}

# Storage Information
output "db_instance_allocated_storage" {
  description = "The amount of allocated storage"
  value       = aws_db_instance.main.allocated_storage
}

output "db_instance_storage_encrypted" {
  description = "Specifies whether the DB instance is encrypted"
  value       = aws_db_instance.main.storage_encrypted
}

# Network Information
output "db_instance_availability_zone" {
  description = "The availability zone of the RDS instance"
  value       = aws_db_instance.main.availability_zone
}

output "db_instance_multi_az" {
  description = "If the RDS instance is multi AZ enabled"
  value       = aws_db_instance.main.multi_az
}

output "db_instance_publicly_accessible" {
  description = "Whether the DB instance is publicly accessible"
  value       = aws_db_instance.main.publicly_accessible
}

# Parameter and Option Groups
output "db_parameter_group_id" {
  description = "The db parameter group name"
  value       = var.create_parameter_group ? aws_db_parameter_group.main[0].id : null
}

output "db_parameter_group_arn" {
  description = "The ARN of the db parameter group"
  value       = var.create_parameter_group ? aws_db_parameter_group.main[0].arn : null
}

output "db_option_group_id" {
  description = "The db option group name"
  value       = var.create_option_group ? aws_db_option_group.main[0].id : null
}

output "db_option_group_arn" {
  description = "The ARN of the db option group"
  value       = var.create_option_group ? aws_db_option_group.main[0].arn : null
}

# Security and Network
output "db_subnet_group_id" {
  description = "The db subnet group name"
  value       = aws_db_subnet_group.main.id
}

output "db_subnet_group_arn" {
  description = "The ARN of the db subnet group"
  value       = aws_db_subnet_group.main.arn
}

output "db_security_group_id" {
  description = "The ID of the security group"
  value       = aws_security_group.rds.id
}

# Monitoring and Logging
output "enhanced_monitoring_iam_role_arn" {
  description = "The Amazon Resource Name (ARN) specifying the monitoring role"
  value       = var.monitoring_interval > 0 ? aws_iam_role.rds_enhanced_monitoring[0].arn : null
}

output "cloudwatch_log_groups" {
  description = "Map of CloudWatch log groups created and their attributes"
  value       = aws_cloudwatch_log_group.this
}

# Secrets Manager
output "secrets_manager_secret_id" {
  description = "The ID of the Secrets Manager secret"
  value       = var.create_secrets_manager_secret ? aws_secretsmanager_secret.db_credentials[0].id : null
}

output "secrets_manager_secret_arn" {
  description = "The ARN of the Secrets Manager secret"
  value       = var.create_secrets_manager_secret ? aws_secretsmanager_secret.db_credentials[0].arn : null
}

# Read Replica
output "read_replica_identifier" {
  description = "The identifier of the read replica"
  value       = var.create_read_replica ? aws_db_instance.read_replica[0].identifier : null
}

output "read_replica_endpoint" {
  description = "The endpoint of the read replica"
  value       = var.create_read_replica ? aws_db_instance.read_replica[0].endpoint : null
}

output "read_replica_arn" {
  description = "The ARN of the read replica"
  value       = var.create_read_replica ? aws_db_instance.read_replica[0].arn : null
}

# Connection String (for applications)
output "connection_string" {
  description = "Database connection string"
  value       = "mysql://${aws_db_instance.main.username}:${var.password != null ? var.password : (length(random_password.db_password) > 0 ? random_password.db_password[0].result : "PASSWORD")}@${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}"
  sensitive   = true
}

# JDBC URL (for Java applications)
output "jdbc_url" {
  description = "JDBC connection URL"
  value       = "jdbc:mysql://${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}?useSSL=true&requireSSL=false&serverTimezone=UTC"
}

# Backup Information
output "latest_restorable_time" {
  description = "The latest time, in UTC RFC3339 format, to which a database can be restored with point-in-time restore"
  value       = aws_db_instance.main.latest_restorable_time
}

output "backup_retention_period" {
  description = "The backup retention period"
  value       = aws_db_instance.main.backup_retention_period
}

output "backup_window" {
  description = "The backup window"
  value       = aws_db_instance.main.backup_window
}

output "maintenance_window" {
  description = "The maintenance window"
  value       = aws_db_instance.main.maintenance_window
}