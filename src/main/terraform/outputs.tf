output "s3_web_arn" {
  value = aws_s3_bucket.web.arn
}
output "s3_app_cdn" {
  value = aws_s3_bucket.cdn.arn
}
output "s3_app_arn" {
  value = aws_s3_bucket.app.arn
}

output "api_gateway_arn" {
  value = aws_apigatewayv2_api.http_api.arn
}

output "lambda_assume_role_arn" {
  value = aws_iam_role.lambda.arn
}