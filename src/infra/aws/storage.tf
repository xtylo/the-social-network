# S3 bucket for creators' media. Bucket names are global across all AWS accounts, so a random suffix is added.

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "content" {
  bucket        = "${var.project}-content-${random_id.bucket_suffix.hex}"
  force_destroy = true # lets `terraform destroy` delete the bucket even if it still has files
}

resource "aws_s3_bucket_public_access_block" "content" {
  bucket = aws_s3_bucket.content.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_cors_configuration" "content" {
  bucket = aws_s3_bucket.content.id

  cors_rule {
    allowed_methods = ["GET", "PUT"]
    allowed_origins = var.allowed_origins
    allowed_headers = ["*"]
    max_age_seconds = 3000
  }
}
