# ECR Repository for yt-backup service
resource "aws_ecr_repository" "yt_backup" {
  name                 = "yt-backup"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "yt-backup"
    Environment = var.environment
  }
}

# ECR Lifecycle Policy to clean up old images
resource "aws_ecr_lifecycle_policy" "yt_backup" {
  repository = aws_ecr_repository.yt_backup.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

output "yt_backup_repository_url" {
  value       = aws_ecr_repository.yt_backup.repository_url
  description = "URL of the yt-backup ECR repository"
}
