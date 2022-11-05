# S3 pictures
output "s3_bucket_arn" {
  value       = module.s3_bucket.s3_bucket_arn
  description = "The ARN of the bucket. Will be of format arn:aws:s3:::bucketname."
}

output "s3_bucket_id" {
  value       = module.s3_bucket.s3_bucket_id
  description = "The name of the bucket."
}