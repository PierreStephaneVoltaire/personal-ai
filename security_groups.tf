# =============================================================================
# EC2 Security Group
# =============================================================================
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "Security group for OpenWebUI and LiteLLM EC2 instances"
  vpc_id      = aws_vpc.main.id

  # No SSH - use SSM Session Manager for access

  # OpenWebUI access
  ingress {
    description = "OpenWebUI"
    from_port   = var.openwebui_port
    to_port     = var.openwebui_port
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # LiteLLM access
  ingress {
    description = "LiteLLM"
    from_port   = var.litellm_port
    to_port     = var.litellm_port
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # HTTP (for potential future use)
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # HTTPS (for potential future use)
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # All outbound traffic
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ec2-sg"
  }
}

# =============================================================================
# RDS Security Group
# =============================================================================
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Security group for PostgreSQL RDS"
  vpc_id      = aws_vpc.main.id

  # PostgreSQL access from EC2 instances
  ingress {
    description     = "PostgreSQL from EC2"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  # PostgreSQL access from allowed CIDRs (for debugging, can be restricted)
  ingress {
    description = "PostgreSQL from allowed CIDRs"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}
