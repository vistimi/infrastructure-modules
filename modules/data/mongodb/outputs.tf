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
output "ec2_instance_mongodb_private_ip" {
  value       = module.ec2_instance_mongodb.private_ip
  description = "The private IP address assigned to the mongodb instance."
}

output "ec2_instance_bastion_public_ip" {
  value       = module.ec2_instance_bastion.*.public_ip
  description = "The public IP address assigned to the bastion instance, if applicable. NOTE: If you are using an aws_eip with your instance, you should refer to the EIP's address directly and not use public_ip as this field will change after the EIP is attached"
}

# output "key_pair_name" {
#   # value       = module.key_pair.*.key_pair_name
#   value = aws_key_pair.key_pair.*.key_pair_name
#   description = "The key pair name"
# }

output "private_key_openssh" {
  # value       = module.key_pair.*.private_key_openssh
  value = tls_private_key.this.*.private_key_openssh
  description = "Private key data in OpenSSH PEM (RFC 4716) format"
  sensitive   = true
}

output "public_key_openssh" {
  # value       = module.key_pair.*.public_key_openssh
  value = tls_private_key.this.*.public_key_openssh
  description = "The public key data in `Authorized Keys` format. This is populated only if the configured private key is supported: this includes all RSA and ED25519 keys"
  sensitive   = false
}
