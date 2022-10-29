output "bucket_arn" {
  value       = aws_s3_bucket.terraform_storage.arn
  description = "The ARN of the S3 bucket"
}

output "locks_arn" {
  value       = aws_dynamodb_table.terraform_locks.arn
  description = "The ARN of the locks"
}