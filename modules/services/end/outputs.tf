# ECS
output "autoscaling_group_name" {
  value       = module.ecs_cluster.autoscaling_group_name
  description = "The name of the Auto Scaling Group"
}

output "autoscaling_group_arn" {
  value       = module.ecs_cluster.autoscaling_group_arn
  description = "ARN of the Auto Scaling Group"
}

output "alb_dns_name" {
  value       = module.ecs_cluster.alb_dns_name
  description = "The domain name of the load balancer"
}

output "alb_security_group_id" {
  value       = module.ecs_cluster.alb_security_group_id
  description = "The ID of the security group"
}

output "alb_security_group_id" {
  value       = module.ecs_cluster.alb_security_group_id
  description = "The ID of the security group"
}