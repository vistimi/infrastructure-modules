output "bucket_arn" {
  value       = module.backend.bucket_arn
  description = "The ARN of the S3 bucket"
}

output "locks_arn" {
  value       = module.backend.locks_arn
  description = "The ARN of the locks"
}