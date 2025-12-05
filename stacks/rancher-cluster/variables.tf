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
  default = "v1.31.13-k3s1"
}

variable "worker_instance_type" {
  type    = string
  default = "m6g.xlarge"
}

variable "worker_count" {
  type    = number
  default = 1
}

variable "stopped" {
  type    = bool
  default = false
}
