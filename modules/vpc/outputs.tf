output "vpc_id" {
  value       = aws_vpc.vpc.id
  description = "The id of the VPC"
}

output "vpc_security_group_id" {
  value       = aws_security_group.vpc.id
  description = "The ID of the Security Group attached to the VPC"
}

output "public_subnets_ids" {
  value = aws_subnet.public_subnet[*].id
  description = "All IDs from the public subnets"
}

output "private_subnets_ids" {
  value = aws_subnet.private_subnet[*].id
  description = "All IDs from the private subnets"
}