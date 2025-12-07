variable "aws_region" {
  type    = string
  default = "ca-central-1"
}

variable "project_name" {
  type    = string
  default = "ai-platform"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "kubernetes_version" {
  type    = string
  default = "v1.31.6+rke2r1"
}

variable "worker_instance_type" {
  type    = string
  default = "c6gn.large"
}

variable "stopped" {
  type    = bool
  default = false
}
