output "arn" {
  value       = aws_s3_bucket.docker.arn
  description = "The ARN of the bucket"
}