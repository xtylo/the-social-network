# S3 bucket for creators' media files.
# Local only: the provider points to Floci (S3 emulator). Phase 2 removes the endpoints block for real AWS.

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

variable "s3_endpoint" {
  description = "S3 endpoint (Floci inside the dev container)."
  type        = string
  default     = "http://floci:4566"
}

variable "bucket_name" {
  description = "Bucket for creators' media files."
  type        = string
  default     = "creator-content"
}

variable "allowed_origins" {
  description = "Web origins allowed to upload with presigned URLs (CORS)."
  type        = list(string)
  default     = ["http://localhost:5173"]
}

provider "aws" {
  region = "us-east-1"

  # Credentials come from AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY (set in the dev container).
  # These flags stop Terraform from calling real AWS services (STS, metadata) that Floci does not need.
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  s3_use_path_style           = true

  endpoints {
    s3 = var.s3_endpoint
  }
}

resource "aws_s3_bucket" "content" {
  bucket = var.bucket_name
}

# The bucket is private: files are only reachable through presigned URLs.
resource "aws_s3_bucket_public_access_block" "content" {
  bucket = aws_s3_bucket.content.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lets a browser app (e.g. a future Vue UI on :5173) upload with presigned URLs.
resource "aws_s3_bucket_cors_configuration" "content" {
  bucket = aws_s3_bucket.content.id

  cors_rule {
    allowed_methods = ["GET", "PUT"]
    allowed_origins = var.allowed_origins
    allowed_headers = ["*"]
    max_age_seconds = 3000
  }
}

output "bucket_name" {
  value = aws_s3_bucket.content.bucket
}