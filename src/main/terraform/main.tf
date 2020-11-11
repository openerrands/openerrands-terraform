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