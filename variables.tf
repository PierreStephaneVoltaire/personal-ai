
variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "personal-llm"
}

variable "max_uptime_minutes" {
  description = "Maximum uptime in minutes before GPU instances are automatically stopped"
  type        = number
  default     = 30
}

variable "models_volume_size_gb" {
  description = "Size of EBS volumes for model storage (in GB)"
  type        = number
  default     = 100
}

variable "models_mount_path" {
  description = "Mount path for models directory"
  type        = string
  default     = "/opt/models"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "Availability zone for resources"
  type        = string
  default     = "us-east-1a"
}

variable "gpu_tiers" {
  description = "GPU tier configurations mapping VRAM requirements to EC2 instance types"
  type = map(object({
    instance_type = string
    vram_gb       = number
    description   = string
  }))
  default = {
    "8gb" = {
      instance_type = "g4dn.xlarge"
      vram_gb       = 16
      description   = "8GB tier - g4dn.xlarge with 16GB VRAM"
    }
    "18gb" = {
      instance_type = "g5.xlarge"
      vram_gb       = 24
      description   = "18GB tier - g5.xlarge with 24GB VRAM"
    }
    "32gb" = {
      instance_type = "g5.4xlarge"
      vram_gb       = 48
      description   = "32GB tier - g5.4xlarge with 48GB VRAM"
    }
  }
}

variable "controller_instance_type" {
  description = "Instance type for the LiteLLM controller"
  type        = string
  default     = "t3.micro"
}
