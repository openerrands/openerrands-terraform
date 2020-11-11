variable "global_prefix" {
  type = string
}
variable "global_domain" {
  type = string
}
variable "environment_prefix" {
  type = string
}

variable "region" {
  type = string
  default = "us-east-2"
}

variable "aws_account_id" {
  type = string
}
variable "cloudflare_zone_id" {
  type = string
}

variable "auth_amazon_client_id" {
  type = string
}
variable "auth_amazon_client_secret" {
  type = string
}

variable "secret_output" {
  type = bool
  default = false
}