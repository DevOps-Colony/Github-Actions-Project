# infra/modules/rds/main.tf

# Random password generation for RDS (if not provided)
resource "random_password" "db_password" {
  count   = var.password == null ? 1 : 0
  length  = 16
  special = true
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.identifier}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.identifier} DB subnet group"
    }
  )
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name_prefix = "${var.identifier}-rds-"
  vpc_id      = var.vpc_id
  description = "Security group for RDS instance ${var.identifier}"

  ingress {
    description     = "MySQL/Aurora from EKS"
    from_port       = var.port
    to_port         = var.port
    protocol        = "tcp"
    security_groups = var.allowed_security_groups
  }

  # Additional ingress rules for specific CIDR blocks (if provided)
  dynamic "ingress" {
    for_each = var.allowed_cidr_blocks
    content {
      description = "MySQL/Aurora from ${ingress.value}"
      from_port   = var.port
      to_port     = var.port
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.identifier}-rds-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Parameter Group for MySQL
resource "aws_db_parameter_group" "main" {
  count       = var.create_parameter_group ? 1 : 0
  family      = var.parameter_group_family
  name        = "${var.identifier}-params"
  description = "Database parameter group for ${var.identifier}"

  # Common MySQL parameters for performance
  dynamic "parameter" {
    for_each = var.parameters
    content {
      name  = parameter.value.name
      value = parameter.value.value
    }
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# Option Group for MySQL (if needed)
resource "aws_db_option_group" "main" {
  count                    = var.create_option_group ? 1 : 0
  name                     = "${var.identifier}-options"
  option_group_description = "Option group for ${var.identifier}"
  engine_name              = var.engine
  major_engine_version     = var.major_engine_version

  dynamic "option" {
    for_each = var.options
    content {
      option_name = option.value.option_name

      dynamic "option_settings" {
        for_each = lookup(option.value, "option_settings", [])
        content {
          name  = option_settings.value.name
          value = option_settings.value.value
        }
      }
    }
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# RDS Instance
resource "aws_db_instance" "main" {
  identifier = var.identifier

  # Engine configuration
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  # Storage configuration
  allocated_storage       = var.allocated_storage
  max_allocated_storage   = var.max_allocated_storage
  storage_type           = var.storage_type
  storage_encrypted      = var.storage_encrypted
  kms_key_id            = var.kms_key_id
  iops                  = var.iops
  storage_throughput    = var.storage_throughput

  # Database configuration
  db_name  = var.db_name
  username = var.username
  password = var.password != null ? var.password : random_password.db_password[0].result
  port     = var.port

  # Network & Security
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  publicly_accessible    = var.publicly_accessible

  # Parameter and Option Groups
  parameter_group_name = var.create_parameter_group ? aws_db_parameter_group.main[0].name : var.parameter_group_name
  option_group_name    = var.create_option_group ? aws_db_option_group.main[0].name : var.option_group_name

  # Backup configuration
  backup_retention_period   = var.backup_retention_period
  backup_window            = var.backup_window
  maintenance_window       = var.maintenance_window
  auto_minor_version_upgrade = var.auto_minor_version_upgrade

  # High Availability
  multi_az = var.multi_az

  # Monitoring
  monitoring_interval             = var.monitoring_interval
  monitoring_role_arn            = var.monitoring_interval > 0 ? aws_iam_role.rds_enhanced_monitoring[0].arn : null
  performance_insights_enabled    = var.performance_insights_enabled
  performance_insights_kms_key_id = var.performance_insights_kms_key_id
  performance_insights_retention_period = var.performance_insights_retention_period

  # Logging
  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports

  # Deletion protection
  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.identifier}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Copy tags to snapshots
  copy_tags_to_snapshot = var.copy_tags_to_snapshot

  tags = merge(
    var.tags,
    {
      Name = var.identifier
    }
  )

  depends_on = [
    aws_db_subnet_group.main,
    aws_security_group.rds
  ]
}

# Enhanced Monitoring Role (if monitoring is enabled)
resource "aws_iam_role" "rds_enhanced_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0
  name  = "${var.identifier}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  count      = var.monitoring_interval > 0 ? 1 : 0
  role       = aws_iam_role.rds_enhanced_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# CloudWatch Log Groups (if logging is enabled)
resource "aws_cloudwatch_log_group" "this" {
  for_each = toset([for log_type in var.enabled_cloudwatch_logs_exports : "/aws/rds/instance/${var.identifier}/${log_type}"])

  name              = each.value
  retention_in_days = var.cloudwatch_log_group_retention_in_days
  kms_key_id        = var.cloudwatch_log_group_kms_key_id

  tags = var.tags
}

# AWS Secrets Manager Secret for Database Credentials (Optional)
resource "aws_secretsmanager_secret" "db_credentials" {
  count                   = var.create_secrets_manager_secret ? 1 : 0
  name                    = "${var.identifier}-credentials"
  description             = "Database credentials for ${var.identifier}"
  recovery_window_in_days = var.secrets_manager_recovery_window_in_days

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  count     = var.create_secrets_manager_secret ? 1 : 0
  secret_id = aws_secretsmanager_secret.db_credentials[0].id
  secret_string = jsonencode({
    username = var.username
    password = var.password != null ? var.password : random_password.db_password[0].result
    engine   = var.engine
    host     = aws_db_instance.main.endpoint
    port     = var.port
    dbname   = var.db_name
  })
}

# Read Replica (Optional)
resource "aws_db_instance" "read_replica" {
  count = var.create_read_replica ? 1 : 0

  identifier = "${var.identifier}-read-replica"

  # Read replica configuration
  replicate_source_db = aws_db_instance.main.identifier
  instance_class      = var.read_replica_instance_class != null ? var.read_replica_instance_class : var.instance_class

  # Storage (inherited from source for read replicas)
  storage_encrypted = var.storage_encrypted

  # Network & Security
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = var.publicly_accessible

  # Monitoring
  monitoring_interval  = var.monitoring_interval
  monitoring_role_arn = var.monitoring_interval > 0 ? aws_iam_role.rds_enhanced_monitoring[0].arn : null

  # Backup (read replicas can have different backup settings)
  backup_retention_period = 0  # Read replicas don't need backups
  skip_final_snapshot    = var.skip_final_snapshot

  # Performance Insights
  performance_insights_enabled    = var.performance_insights_enabled
  performance_insights_kms_key_id = var.performance_insights_kms_key_id

  # Auto minor version upgrade
  auto_minor_version_upgrade = var.auto_minor_version_upgrade

  tags = merge(
    var.tags,
    {
      Name = "${var.identifier}-read-replica"
      Type = "read-replica"
    }
  )
}