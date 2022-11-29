# ECS
output "autoscaling_group_name_on_demand" {
  value       = module.ecs_cluster.autoscaling_group_name_on_demand
  description = "The name of the Auto Scaling Group"
}

output "autoscaling_group_arn_on_demand" {
  value       = module.ecs_cluster.autoscaling_group_arn_on_demand
  description = "ARN of the Auto Scaling Group"
}

# output "autoscaling_group_name_spot" {
#   value       = module.ecs_cluster.autoscaling_group_name_spot
#   description = "The name of the Auto Scaling Group"
# }

# output "autoscaling_group_arn_spot" {
#   value       = module.ecs_cluster.autoscaling_group_arn_spot
#   description = "ARN of the Auto Scaling Group"
# }

output "alb_dns_name" {
  value       = module.ecs_cluster.alb_dns_name
  description = "The domain name of the load balancer"
}

output "alb_security_group_id" {
  value       = module.ecs_cluster.alb_security_group_id
  description = "The ID of the security group"
}

output "ecs_task_definition_arn" {
  value       = aws_ecs_task_definition.service.arn
  description = "Full ARN of the Task Definition (including both family and revision)"
}

output "ecs_task_definition_revision" {
  value       = aws_ecs_task_definition.service.revision
  description = "Revision of the task in a particular family"
}

# MongoDB
output "ec2_instance_mongodb_private_ip" {
  value       = module.mongodb.ec2_instance_mongodb_private_ip
  description = "The private IP address assigned to the mongodb instance."
}