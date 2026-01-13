# DynamoDB Table: youtube-live-notifications
# Stores notifications for YouTube live streams with TTL
resource "aws_dynamodb_table" "youtube_live_notifications" {
  name         = "youtube-live-notifications"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "videoId"

  attribute {
    name = "videoId"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = {
    Name        = "youtube-live-notifications"
    Environment = var.environment
    Purpose     = "YouTube live stream notifications tracking"
  }
}

# DynamoDB Table: youtube-channel-cache
# Caches YouTube channel metadata
resource "aws_dynamodb_table" "youtube_channel_cache" {
  name         = "youtube-channel-cache"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "handle"

  attribute {
    name = "handle"
    type = "S"
  }

  attribute {
    name = "channelId"
    type = "S"
  }

  global_secondary_index {
    name            = "channelId-index"
    hash_key        = "channelId"
    projection_type = "ALL"
  }

  tags = {
    Name        = "youtube-channel-cache"
    Environment = var.environment
    Purpose     = "YouTube channel metadata cache"
  }
}

# S3 Bucket for YouTube video backups
resource "aws_s3_bucket" "youtube_backup" {
  bucket = "${var.project_name}-youtube-backup"

  tags = {
    Name        = "${var.project_name}-youtube-backup"
    Environment = var.environment
    Purpose     = "YouTube video backup storage"
  }
}

# Enable versioning for backup bucket
resource "aws_s3_bucket_versioning" "youtube_backup" {
  bucket = aws_s3_bucket.youtube_backup.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption for backup bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "youtube_backup" {
  bucket = aws_s3_bucket.youtube_backup.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access to backup bucket
resource "aws_s3_bucket_public_access_block" "youtube_backup" {
  bucket = aws_s3_bucket.youtube_backup.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# SSM Parameter for YouTube cookies
resource "aws_ssm_parameter" "youtube_cookies" {
  name        = "/${var.project_name}/${var.environment}/youtube/cookies"
  description = "YouTube cookies for authenticated video downloads"
  type        = "SecureString"
  tier        = "Advanced"
  value       = "# Placeholder - Update with actual cookies from browser export"

  lifecycle {
    ignore_changes = [value]
  }

  tags = {
    Name        = "youtube-cookies"
    Environment = var.environment
  }
}

# SSM Parameter Store for n8n credentials
resource "random_password" "n8n_password" {
  length  = 32
  special = true
}

resource "aws_ssm_parameter" "n8n_password" {
  name        = "/${var.project_name}/${var.environment}/n8n/password"
  description = "n8n admin password"
  type        = "SecureString"
  value       = random_password.n8n_password.result

  tags = {
    Name        = "n8n-password"
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "n8n_email" {
  name        = "/${var.project_name}/${var.environment}/n8n/email"
  description = "n8n admin email"
  type        = "String"
  value       = var.email

  tags = {
    Name        = "n8n-email"
    Environment = var.environment
  }
}

# Outputs
output "youtube_live_notifications_table" {
  value       = aws_dynamodb_table.youtube_live_notifications.name
  description = "DynamoDB table for YouTube live notifications"
}

output "youtube_channel_cache_table" {
  value       = aws_dynamodb_table.youtube_channel_cache.name
  description = "DynamoDB table for YouTube channel cache"
}

output "youtube_backup_bucket" {
  value       = aws_s3_bucket.youtube_backup.id
  description = "S3 bucket for YouTube video backups"
}

output "youtube_cookies_parameter" {
  value       = aws_ssm_parameter.youtube_cookies.name
  description = "SSM parameter name for YouTube cookies"
}

output "n8n_password_parameter" {
  value       = aws_ssm_parameter.n8n_password.name
  description = "SSM parameter name for n8n password"
}

output "n8n_email_parameter" {
  value       = aws_ssm_parameter.n8n_email.name
  description = "SSM parameter name for n8n email"
}

output "n8n_admin_password" {
  value       = random_password.n8n_password.result
  description = "n8n admin password (initial setup)"
  sensitive   = true
}
