// Defines the AWS infrastructure with Terraform to deploy the required services.

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "content_bucket" {
  bucket = "creator-content-bucket"
  acl    = "private"
}

resource "aws_api_gateway_rest_api" "api" {
  name = "creator-api"
}

resource "aws_lambda_function" "recommendation_handler" {
  function_name = "recommendationHandler"
  handler       = "bootstrap"
  runtime       = "provided.al2"
  role          = aws_iam_role.lambda_exec.arn
  filename      = "./lambda/recommendation.zip"
}
