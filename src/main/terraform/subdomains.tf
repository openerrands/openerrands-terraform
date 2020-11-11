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
  target = "${cloudflare_record.www[0].name}/*"

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