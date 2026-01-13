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
    model_name  = string
    model_id    = string
    max_tokens  = number
    temperature = number
  }))
}

variable "openrouter_api_key" {
  type      = string
  sensitive = true
}

variable "n8n_secrets" {

  description = "Map of secrets to inject as environment variables into n8n"

  type = map(string)

  sensitive = true

  default = {}

}



variable "aws_access_key" {

  type = string

  sensitive = true

}



variable "aws_secret_key" {

  type = string

  sensitive = true

}

variable "mcp_filesystem_mount_paths" {
  description = "List of host paths to mount into the MCP server container for the filesystem server"
  type        = list(string)
  default     = []
}
