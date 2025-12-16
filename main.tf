locals {
  cluster_name = "${var.project_name}-${var.environment}"
}

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_s3_object" "council_main" {
  bucket = aws_s3_bucket.ai_storage.id
  key    = "council/main.py"
  source = "${path.module}/council/main.py"
  etag   = filemd5("${path.module}/council/main.py")
}

resource "aws_s3_object" "council_graph" {
  bucket = aws_s3_bucket.ai_storage.id
  key    = "council/graph.py"
  source = "${path.module}/council/graph.py"
  etag   = filemd5("${path.module}/council/graph.py")
}

resource "aws_s3_object" "council_client" {
  bucket = aws_s3_bucket.ai_storage.id
  key    = "council/client.py"
  source = "${path.module}/council/client.py"
  etag   = filemd5("${path.module}/council/client.py")
}

resource "aws_s3_object" "council_requirements" {
  bucket = aws_s3_bucket.ai_storage.id
  key    = "council/requirements.txt"
  source = "${path.module}/council/requirements.txt"
  etag   = filemd5("${path.module}/council/requirements.txt")
}
