# EC2
output "ec2_instance_arn" {
  value       = module.mongodb.ec2_instance_arn
  description = "The ARN of the instance"
}

output "ec2_instance_private_ip" {
  value       = module.mongodb.ec2_instance_private_ip
  description = "The private IP address assigned to the instance."
}

output "ec2_instance_public_ip" {
  value       = module.mongodb.ec2_instance_public_ip
  description = "The public IP address assigned to the instance, if applicable. NOTE: If you are using an aws_eip with your instance, you should refer to the EIP's address directly and not use public_ip as this field will change after the EIP is attached"
}