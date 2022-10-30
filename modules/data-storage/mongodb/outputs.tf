# S3 mongodb
output "s3_bucket_mongodb_arn" {
  value       = module.s3_bucket_mongodb.s3_bucket_arn
  description = "The ARN of the bucket. Will be of format arn:aws:s3:::bucketname."
}

output "s3_bucket_mongodb_id" {
  value       = module.s3_bucket_mongodb.s3_bucket_id
  description = "The name of the bucket."
}

# S3 pictures
output "s3_bucket_pictures_arn" {
  value       = module.s3_bucket_pictures.s3_bucket_arn
  description = "The ARN of the bucket. Will be of format arn:aws:s3:::bucketname."
}

output "s3_bucket_pictures_id" {
  value       = module.s3_bucket_pictures.s3_bucket_id
  description = "The name of the bucket."
}

# EC2
output "ec2_instance_arn" {
  value       = module.ec2_instance.arn
  description = "The ARN of the instance"
}

output "ec2_instance_private_ip" {
  value       = module.ec2_instance.private_ip
  description = "The private IP address assigned to the instance."
}

output "ec2_instance_public_ip" {
  value       = module.ec2_instance.public_ip
  description = "The public IP address assigned to the instance, if applicable. NOTE: If you are using an aws_eip with your instance, you should refer to the EIP's address directly and not use public_ip as this field will change after the EIP is attached"
}