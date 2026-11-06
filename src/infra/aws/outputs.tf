output "db_address" {
  description = "RDS endpoint host name."
  value       = aws_db_instance.main.address
}

output "database_url" {
  description = "Connection URL with TLS. Read it with: terraform output -raw database_url"
  value       = "postgres://${aws_db_instance.main.username}:${random_password.db.result}@${aws_db_instance.main.address}:5432/${aws_db_instance.main.db_name}?sslmode=require"
  sensitive   = true
}

output "bucket_name" {
  description = "S3 bucket for media files."
  value       = aws_s3_bucket.content.bucket
}
