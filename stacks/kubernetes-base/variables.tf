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

variable "zerossl_eab_kid" {
  type      = string
  sensitive = true
  default   = ""
}

variable "zerossl_eab_hmac_key" {
  type      = string
  sensitive = true
  default   = ""
}
