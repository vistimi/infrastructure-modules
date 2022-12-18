output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "The ID of the VPC"
}

output "vpc_cidr_block" {
  value       = module.vpc.vpc_cidr_block
  description = "The CIDR block of the VPC"
}

output "default_security_group_id" {
  value       = module.vpc.default_security_group_id
  description = "The ID of the security group created by default on VPC creation"
}

output "private_subnets" {
  value       = module.vpc.private_subnets
  description = "List of IDs of private subnets"
}

output "public_subnets" {
  value       = module.vpc.public_subnets
  description = "List of IDs of public subnets"
}

output "nat_ids" {
  value       = module.vpc.nat_ids
  description = "List of allocation ID of Elastic IPs created for AWS NAT Gateway"
}

output "nat_public_ips" {
  value       = module.vpc.nat_public_ips
  description = "List of public Elastic IPs created for AWS NAT Gateway"
}

output "natgw_ids" {
  value       = module.vpc.natgw_ids
  description = "List of NAT Gateway IDs"
}

output "private_nat_gateway_route_ids" {
  value       = module.vpc.private_nat_gateway_route_ids
  description = "List of IDs of the private nat gateway route"
}