output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "The ID of the VPC"
}

output "default_security_group_id" {
  value       = module.vpc.default_security_group_id
  description = "The ID of the security group created by default on VPC creation"
}

output "private_subnets" {
  value = module.vpc.private_subnets
  description = "List of IDs of private subnets"
}

output "public_subnets" {
  value = module.vpc.public_subnets
  description = "List of IDs of public subnets"
}