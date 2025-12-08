variable "aws_region" {
  type    = string
  default = "ca-central-1"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "domain_name" {
  type = string
}

variable "openrouter_api_key" {
  type      = string
  sensitive = true
}


variable "timezone" {
  type    = string
  default = "America/Toronto"
}

variable "litellm_models" {
  type = list(object({
    model_name = string
    model_id   = string
  }))
  default = []
}

variable "stopped" {
  type    = bool
  default = false
}
