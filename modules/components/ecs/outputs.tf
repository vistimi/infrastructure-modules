# ASG
output "autoscaling_group_name_on_demand" {
  value       = module.asg["on-demand"].autoscaling_group_name
  description = "Name of the Auto Scaling Group"
}

output "autoscaling_group_arn_on_demand" {
  value       = module.asg["on-demand"].autoscaling_group_arn
  description = "ARN of the Auto Scaling Group"
}

# output "autoscaling_group_name_spot" {
#   value       = module.asg["spot"].autoscaling_group_name
#   description = "Name of the Auto Scaling Group"
# }

# output "autoscaling_group_arn_spot" {
#   value       = module.asg["spot"].autoscaling_group_arn
#   description = "ARN of the Auto Scaling Group"
# }

output "alb_dns_name" {
  value       = module.alb.lb_dns_name
  description = "The domain name of the load balancer"
}

output "alb_security_group_id" {
  value       = module.alb_sg.security_group_id
  description = "The ID of the security group"
}