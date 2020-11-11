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