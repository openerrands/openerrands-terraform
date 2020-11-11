terraform {
  required_version = ">= 0.13"

  backend "s3" {
    encrypt = true
  }

  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 3.13.0"
    }
    cloudflare = {
      source = "cloudflare/cloudflare"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  assume_role {
    role_arn = "arn:aws:iam::${var.aws_account_id}:role/OrganizationAccountAccessRole"
  }
}

provider "cloudflare" {
  version = "~> 2.0"
  # Credentials automatically from CLOUDFLARE_API_TOKEN environment variable
}



resource "aws_s3_bucket" "cdn" {
  bucket = var.environment_prefix == "prod" ? "cdn.${var.global_domain}" : "cdn-${var.environment_prefix}.${var.global_domain}"
  acl = "public-read"
  website {
    index_document = "index.html"
    error_document = "error.html"
  }
}

data "aws_iam_policy_document" "cdn" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.cdn.arn}/*"]
    principals {
      type = "AWS"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_policy" "cdn" {
  bucket = aws_s3_bucket.cdn.id
  policy = data.aws_iam_policy_document.cdn.json
}

resource "cloudflare_record" "cdn" {
  zone_id = var.cloudflare_zone_id
  type = "CNAME"
  name = var.environment_prefix == "prod" ? "cdn.${var.global_domain}" : "cdn-${var.environment_prefix}.${var.global_domain}"
  value = aws_s3_bucket.cdn.website_endpoint
  proxied = true
}



resource "aws_s3_bucket" "web" {
  bucket = var.environment_prefix == "prod" ? var.global_domain : "${var.environment_prefix}.${var.global_domain}"
  acl = "public-read"

  website {
    index_document = "index.html"
    error_document = "error.html"
  }
}

data "aws_iam_policy_document" "web" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.web.arn}/*"]
    principals {
      type = "AWS"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_policy" "web" {
  bucket = aws_s3_bucket.web.id
  policy = data.aws_iam_policy_document.web.json
}

resource "cloudflare_record" "web" {
  zone_id = var.cloudflare_zone_id
  type = "CNAME"
  name = var.environment_prefix == "prod" ? var.global_domain : "${var.environment_prefix}.${var.global_domain}"
  value = aws_s3_bucket.web.website_endpoint
  proxied = true
}

resource "cloudflare_record" "www" {
  count = var.environment_prefix == "prod" ? 1 : 0

  zone_id = var.cloudflare_zone_id
  type = "CNAME"
  name = "www.${var.global_domain}"
  value = aws_s3_bucket.web.website_endpoint // Doesn't matter - see redirect below
  proxied = true
}

resource "cloudflare_page_rule" "www" {
  count = var.environment_prefix == "prod" ? 1 : 0

  zone_id = var.cloudflare_zone_id
  target = cloudflare_record.www[0].name

  actions {
    forwarding_url {
      url = "https://${var.global_domain}/$1"
      status_code = 301
    }
  }
}



resource "aws_s3_bucket" "app" {
  bucket = var.environment_prefix == "prod" ? "app.${var.global_domain}" : "app-${var.environment_prefix}.${var.global_domain}"
  acl = "public-read"
  website {
    index_document = "index.html"
    error_document = "error.html"
  }
}

data "aws_iam_policy_document" "app" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.app.arn}/*"]
    principals {
      type = "AWS"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_policy" "app" {
  bucket = aws_s3_bucket.app.id
  policy = data.aws_iam_policy_document.app.json
}

resource "cloudflare_record" "app" {
  zone_id = var.cloudflare_zone_id
  type = "CNAME"
  name = var.environment_prefix == "prod" ? "app.${var.global_domain}" : "app-${var.environment_prefix}.${var.global_domain}"
  value = aws_s3_bucket.app.website_endpoint
  proxied = true
}



resource "aws_acm_certificate" "api" {
  domain_name = var.environment_prefix == "prod" ? "api.${var.global_domain}" : "api-${var.environment_prefix}.${var.global_domain}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "cloudflare_record" "api_validation" {
  for_each = {
    for dvo in aws_acm_certificate.api.domain_validation_options : dvo.domain_name => {
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

resource "aws_acm_certificate_validation" "api" {
  certificate_arn         = aws_acm_certificate.api.arn
  validation_record_fqdns = [for record in cloudflare_record.api_validation : record.hostname]
}

resource "aws_apigatewayv2_api" "http_api" {
  name          = "http_api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_domain_name" "http_api" {
  domain_name = aws_acm_certificate.api.domain_name

  domain_name_configuration {
    certificate_arn = aws_acm_certificate.api.arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "cloudflare_record" "api" {
  zone_id = var.cloudflare_zone_id
  type = "CNAME"
  name = aws_apigatewayv2_domain_name.http_api.domain_name
  value = aws_apigatewayv2_domain_name.http_api.domain_name_configuration[0].target_domain_name
  ttl = 60
}

resource "aws_apigatewayv2_stage" "http_api" {
  api_id = aws_apigatewayv2_api.http_api.id
  name   = "$default"
  auto_deploy = true

  stage_variables = {
    s3_cdn_bucket = aws_s3_bucket.cdn.bucket,
    s3_cdn_domain = cloudflare_record.cdn.hostname,
    s3_cdn_endpoint = aws_s3_bucket.cdn.website_endpoint,
    s3_app_bucket = aws_s3_bucket.app.bucket,
    s3_cdn_domain = cloudflare_record.app.hostname,
    s3_app_endpoint = aws_s3_bucket.app.website_endpoint,
    api_gateway_endpoint = trimprefix(aws_apigatewayv2_api.http_api.api_endpoint, "https://"),
    api_gateway_domain = cloudflare_record.api.hostname
  }
}

data "aws_iam_policy_document" "lambda" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name = "LambdaRole"
  assume_role_policy = data.aws_iam_policy_document.lambda.json
}