resource "aws_s3_bucket" "ai_storage" {
  bucket = "pv-ai-bucket"

  tags = {
    Name = "${local.cluster_name}-storage"
  }
}

resource "aws_s3_bucket_versioning" "ai_storage" {
  bucket = aws_s3_bucket.ai_storage.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ai_storage" {
  bucket = aws_s3_bucket.ai_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "ai_storage" {
  bucket = aws_s3_bucket.ai_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "ai_storage" {
  bucket = aws_s3_bucket.ai_storage.id

  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}
