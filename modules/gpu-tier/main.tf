variable "tier_name" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "vram_gb" {
  type = number
}

variable "ebs_size_gb" {
  type = number
}

variable "ami_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "iam_instance_profile" {
  type = string
}

variable "project_name" {
  type = string
}

data "aws_subnet" "selected" {
  id = var.subnet_id
}

resource "aws_ebs_volume" "models" {
  availability_zone = data.aws_subnet.selected.availability_zone
  size              = var.ebs_size_gb
  type              = "gp3"

  tags = {
    Name = "${var.project_name}-${var.tier_name}-models"
    Tier = var.tier_name
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_instance" "gpu" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = var.iam_instance_profile

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    volume_id   = aws_ebs_volume.models.id
    tier_name   = var.tier_name
    models_path = "/opt/models"
  }))

  tags = {
    Name     = "${var.project_name}-${var.tier_name}"
    Tier     = var.tier_name
    VramGB   = var.vram_gb
    AutoStop = "true"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

resource "aws_eip" "gpu" {
  instance = aws_instance.gpu.id
  domain   = "vpc"

  tags = { Name = "${var.project_name}-${var.tier_name}-eip" }
}

output "instance_id" {
  value = aws_instance.gpu.id
}

output "public_ip" {
  value = aws_eip.gpu.public_ip
}

output "private_ip" {
  value = aws_instance.gpu.private_ip
}

output "elastic_ip" {
  value = aws_eip.gpu.public_ip
}

output "volume_id" {
  value = aws_ebs_volume.models.id
}

output "vram_gb" {
  value = var.vram_gb
}
