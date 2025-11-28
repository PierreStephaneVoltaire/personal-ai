variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "ollama-gpu"
}

variable "allowed_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to access LiteLLM and OpenWebUI"
  default     = ["0.0.0.0/0"]
}

variable "controller_instance_type" {
  type    = string
  default = "t3.small"
}

variable "max_uptime_minutes" {
  type    = number
  default = 30
}

variable "gpu_tiers" {
  type = map(object({
    instance_type = string
    vram_gb       = number
    ebs_size_gb   = number
  }))
  default = {
    "8gb" = {
      instance_type = "g4dn.xlarge"
      vram_gb       = 16
      ebs_size_gb   = 50
    }
    "18gb" = {
      instance_type = "g5.xlarge"
      vram_gb       = 24
      ebs_size_gb   = 100
    }
    "32gb" = {
      instance_type = "g5.4xlarge"
      vram_gb       = 48
      ebs_size_gb   = 200
    }
  }
}

variable "enable_knowledge_base" {
  type    = bool
  default = false
}

variable "knowledge_base_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "knowledge_base_volume_size_gb" {
  type    = number
  default = 50
}

variable "enable_functions" {
  type    = bool
  default = false
}
