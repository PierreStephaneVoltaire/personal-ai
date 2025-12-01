# =============================================================================
# Random password for RDS
# =============================================================================
resource "random_password" "db_password" {
  length           = 32
  special          = true
 override_special = "!#$%&*()-_=+[]{}<>?"
 }

# =============================================================================
# RDS PostgreSQL Instance
# =============================================================================
resource "aws_db_instance" "postgres" {
  identifier = "${var.project_name}-postgres"

  engine               = "postgres"
  engine_version       = "17"
  instance_class       = var.db_instance_class
  allocated_storage    = var.db_allocated_storage
  max_allocated_storage = var.db_allocated_storage * 2

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Make it publicly accessible (since we're in public subnets)
  publicly_accessible = true

  # Storage
  storage_type      = "gp3"
  storage_encrypted = true

  # Backup and maintenance
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "Mon:04:00-Mon:05:00"

  # Disable Performance Insights to save costs
  performance_insights_enabled = false

  # Deletion protection (disable for dev)
  deletion_protection = var.environment == "prod" ? true : false
  skip_final_snapshot = var.environment != "prod"
  final_snapshot_identifier = var.environment == "prod" ? "${var.project_name}-final-snapshot" : null

  # Apply changes immediately in dev
  apply_immediately = var.environment != "prod"

  tags = {
    Name = "${var.project_name}-postgres"
  }
}

# =============================================================================
# Store DB password in Parameter Store
# =============================================================================
resource "aws_ssm_parameter" "db_password" {
  name        = "/${var.project_name}/db/password"
  description = "PostgreSQL database password"
  type        = "SecureString"
  value       = random_password.db_password.result

  tags = {
    Name = "${var.project_name}-db-password"
  }
}

resource "aws_ssm_parameter" "db_host" {
  name        = "/${var.project_name}/db/host"
  description = "PostgreSQL database host"
  type        = "String"
  value       = aws_db_instance.postgres.address

  tags = {
    Name = "${var.project_name}-db-host"
  }
}

resource "aws_ssm_parameter" "db_connection_string" {
  name        = "/${var.project_name}/db/connection_string"
  description = "PostgreSQL database connection string"
  type        = "SecureString"
  value       = "postgresql://${var.db_username}:${urlencode(random_password.db_password.result)}@${aws_db_instance.postgres.address}:5432/${var.db_name}"

  tags = {
    Name = "${var.project_name}-db-connection-string"
  }
}
