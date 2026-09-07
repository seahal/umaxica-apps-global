output "bucket" {
  description = "Bucket name, for wiring into the application's OBJECT_STORAGE_BUCKET_* variable."
  value       = aws_s3_bucket.this.bucket
}

output "arn" {
  description = "Bucket ARN, for IAM policy documents."
  value       = aws_s3_bucket.this.arn
}
