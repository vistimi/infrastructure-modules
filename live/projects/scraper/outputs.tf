output "vpc_id" {
  value       = module.vpc.id
  description = "The id of the VPC"
}

output "vpc_security_group_id" {
  value       = module.vpc.security_group_id
  description = "The ID of the Security Group attached to the VPC"
}

output "vpc_public_subnets_ids" {
  value = module.vpc.public_subnets_ids
  description = "All IDs from the public subnets"
}

output "vpc_private_subnets_ids" {
  value = module.vpc.private_subnets_ids
  description = "All IDs from the private subnets"
}