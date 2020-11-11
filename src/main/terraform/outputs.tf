output "s3_web_arn" {
  value = aws_s3_bucket.web.arn
}
output "s3_web_bucket" {
  value = aws_s3_bucket.web.bucket
}
output "s3_web_endpoint" {
  value = aws_s3_bucket.web.website_endpoint
}

output "s3_cdn_arn" {
  value = aws_s3_bucket.cdn.arn
}
output "s3_cdn_bucket" {
  value = aws_s3_bucket.cdn.bucket
}
output "s3_cdn_endpoint" {
  value = aws_s3_bucket.cdn.website_endpoint
}

output "s3_app_arn" {
  value = aws_s3_bucket.app.arn
}
output "s3_app_bucket" {
  value = aws_s3_bucket.app.bucket
}
output "s3_app_endpoint" {
  value = aws_s3_bucket.app.website_endpoint
}

output "api_gateway_arn" {
  value = aws_apigatewayv2_api.http_api.arn
}

output "lambda_role_arn" {
  value = aws_iam_role.lambda.arn
}