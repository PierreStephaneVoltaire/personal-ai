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
data "template_file" "user_data" {
  template = file("${path.module}/templates/user_data.sh")

  vars = {
    project_name   = var.project_name
    aws_region     = var.aws_region
    openwebui_port = var.openwebui_port
    litellm_port   = var.litellm_port
  }
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
  user_data = base64encode(data.template_file.user_data.rendered)

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
