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

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "instance_type" {
  type    = string
  default = "m6g.xlarge"
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

variable "email" {
  type = string
}

variable "timezone" {
  type    = string
  default = "America/Toronto"
}

variable "litellm_models" {
  type = list(object({
    model_name    = string
    model_id      = string
    system_prompt = string
    max_tokens    = number
    temperature   = number
  }))
}

variable "openrouter_api_key" {
  type      = string
  sensitive = true
}

variable "council_members" {
  type = map(object({
    model_id      = string
    role          = string
    max_tokens    = number
    temperature   = number
    name          = string
    system_prompt = string
  }))
}
