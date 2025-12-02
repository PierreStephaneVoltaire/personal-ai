# =============================================================================
# Get latest Ubuntu 22.04 AMI
# =============================================================================
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# =============================================================================
# User Data Template
# =============================================================================
locals {
  mcpo_api_key = random_password.mcpo_key.result

  mcpo_config = jsonencode({
    mcpServers = {
      aws = {
        command = "docker"
        args = [
          "run", "-i", "--rm",
          "-e", "AWS_PROFILE=default",
          "-e", "AWS_REGION=${var.aws_region}",
          "-v", "$HOME/.aws:/root/.aws:ro",
          "alexei-led/aws-mcp-server:latest"
        ]
      }
      azure = {
        command = "npx"
        args    = ["-y", "azure-cli-mcp"]
      }
      github = {
        command = "npx"
        args    = ["-y", "@modelcontextprotocol/server-github"]
        env = {
          GITHUB_PERSONAL_ACCESS_TOKEN = var.github_token
        }
      }
      kubernetes = {
        command = "docker"
        args = [
          "run", "-i", "--rm",
          "-v", "$HOME/.kube:/root/.kube:ro",
          "rohitg00/kubectl-mcp-server:latest"
        ]
      }
      docker = {
        command = "npx"
        args    = ["-y", "@modelcontextprotocol/server-docker"]
      }
      terraform = {
        command = "docker"
        args = [
          "run", "-i", "--rm",
          "hashicorp/terraform-mcp-server:latest"
        ]
      }
      google-maps = {
        command = "npx"
        args    = ["-y", "mcp-server-google-maps"]
        env = {
          GOOGLE_MAPS_API_KEY = var.google_maps_api_key
        }
      }
      time = {
        command = "uvx"
        args    = ["mcp-server-time", "--local-timezone=America/Toronto"]
      }
      wikipedia = {
        command = "npx"
        args    = ["-y", "@modelcontextprotocol/server-wikipedia"]
      }
      youtube = {
        command = "npx"
        args    = ["-y", "mcp-youtube-transcript"]
      }
      memory = {
        command = "npx"
        args    = ["-y", "@modelcontextprotocol/server-memory"]
      }
      filesystem = {
        command = "npx"
        args    = ["-y", "@modelcontextprotocol/server-filesystem", "/workspace"]
      }
    }
  })

  docker_compose_content = templatefile("${path.module}/templates/docker-compose.yml.tpl", {
    openwebui_port = var.openwebui_port
    litellm_port   = var.litellm_port
    default_model  = var.default_model
    mcpo_api_key   = local.mcpo_api_key
  })

  user_data = templatefile("${path.module}/templates/user_data.sh", {
    project_name           = var.project_name
    aws_region             = var.aws_region
    docker_compose_content = local.docker_compose_content
    mcpo_config_content    = local.mcpo_config
    mcpo_api_key           = local.mcpo_api_key
  })
}

resource "random_password" "mcpo_key" {
  length  = 32
  special = false
}

output "mcpo_api_key" {
  value     = random_password.mcpo_key.result
  sensitive = true
}
# =============================================================================
# Launch Template
# =============================================================================
resource "aws_launch_template" "main" {
  name          = "${var.project_name}-launch-template"
  description   = "Launch template for OpenWebUI and LiteLLM"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  # No SSH key - use SSM Session Manager

  # IAM Instance Profile
  iam_instance_profile {
    arn = aws_iam_instance_profile.ec2.arn
  }

  # Network interfaces
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ec2.id]
    delete_on_termination       = true
  }

  # Storage
  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  # Basic monitoring only (detailed monitoring costs extra)
  monitoring {
    enabled = false
  }

  # Metadata options (IMDSv2)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  # User data
  user_data = base64encode(local.user_data)

  # Instance tags
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-instance"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name = "${var.project_name}-volume"
    }
  }

  tags = {
    Name = "${var.project_name}-launch-template"
  }

  # Ensure dependencies are met
  depends_on = [
    aws_db_instance.postgres,
    aws_ssm_parameter.db_connection_string,
    aws_ssm_parameter.openrouter_api_key,
    aws_ssm_parameter.litellm_master_key
  ]
}
