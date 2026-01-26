# ECR Repository for mcp-server
resource "aws_ecr_repository" "mcp_server" {
  name                 = "mcp-server"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "mcp-server"
    Environment = var.environment
    Project     = "ai-platform"
    ManagedBy   = "Terraform"
  }
}

resource "aws_ecr_lifecycle_policy" "mcp_server" {
  repository = aws_ecr_repository.mcp_server.name

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

output "mcp_server_repository_url" {
  value       = aws_ecr_repository.mcp_server.repository_url
  description = "URL of the mcp-server ECR repository"
}
