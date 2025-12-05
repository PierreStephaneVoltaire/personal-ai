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

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "rancher_instance_type" {
  type    = string
  default = "t4g.medium"
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