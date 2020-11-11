provider "aws" {
  assume_role {
    role_arn = "arn:aws:iam::${var.aws_account_id}:role/OrganizationAccountAccessRole"
  }
  region = "us-east-1"
  alias = "cognito"
}

resource "aws_acm_certificate" "auth" {
  provider = aws.cognito
  domain_name = var.environment_prefix == "prod" ? "auth.${var.global_domain}" : "auth-${var.environment_prefix}.${var.global_domain}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "cloudflare_record" "auth_validation" {
  for_each = {
  for dvo in aws_acm_certificate.auth.domain_validation_options : dvo.domain_name => {
    name   = dvo.resource_record_name
    record = dvo.resource_record_value
    type   = dvo.resource_record_type
  }
  }

  zone_id = var.cloudflare_zone_id
  type = each.value.type
  name = each.value.name
  value = trim(each.value.record, ".")
  ttl = 60
}

resource "aws_acm_certificate_validation" "auth" {
  provider = aws.cognito
  certificate_arn         = aws_acm_certificate.auth.arn
  validation_record_fqdns = [for record in cloudflare_record.auth_validation : record.hostname]
}

resource "aws_cognito_user_pool" "auth" {
  name = "auth"
  admin_create_user_config {
    allow_admin_create_user_only = true
  }
}

resource "aws_cognito_user_pool_domain" "auth" {
  domain = aws_acm_certificate.auth.domain_name
  certificate_arn = aws_acm_certificate.auth.arn
  user_pool_id = aws_cognito_user_pool.auth.id
}

resource "cloudflare_record" "auth" {
  zone_id = var.cloudflare_zone_id
  type = "CNAME"
  name = aws_cognito_user_pool_domain.auth.domain
  value = aws_cognito_user_pool_domain.auth.cloudfront_distribution_arn // Actually a domain name, not a ARN
  ttl = 60
}


resource "aws_cognito_identity_provider" "example_provider" {
  user_pool_id  = aws_cognito_user_pool.auth.id
  provider_name = "LoginWithAmazon"
  provider_type = "LoginWithAmazon"

  provider_details = {
    authorize_scopes = "profile"
    client_id        = var.auth_amazon_client_id
    client_secret    = var.auth_amazon_client_secret

    attributes_url = "https://api.amazon.com/user/profile"
    attributes_url_add_attributes = false
    authorize_url = "https://www.amazon.com/ap/oa"
    token_request_method = "POST"
    token_url= "https://api.amazon.com/auth/o2/token"
  }

  attribute_mapping = {
    username = "user_id"
    email = "email"
    name = "name"
  }
}