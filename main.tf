terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  gpu_tier_instance_type = { for k, v in var.gpu_tiers : k => v.instance_type }
  gpu_tier_vram          = { for k, v in var.gpu_tiers : k => v.vram_gb }
  gpu_tier_ebs_size      = { for k, v in var.gpu_tiers : k => v.ebs_size_gb }
  gpu_ami                = data.aws_ami.deep_learning.id
  controller_ami         = data.aws_ami.al2023.id
}



data "aws_ami" "deep_learning" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_caller_identity" "current" {}

resource "random_password" "litellm_master_key" {
  length  = 32
  special = false
}
