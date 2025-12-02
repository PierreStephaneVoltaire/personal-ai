# =============================================================================
# S3 Bucket for OpenWebUI File Storage
# =============================================================================
resource "aws_s3_bucket" "openwebui" {
  bucket = var.s3_bucket_name

  tags = {
    Name        = "${var.project_name}-storage"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "openwebui" {
  bucket = aws_s3_bucket.openwebui.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "openwebui" {
  bucket = aws_s3_bucket.openwebui.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "openwebui" {
  bucket = aws_s3_bucket.openwebui.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
