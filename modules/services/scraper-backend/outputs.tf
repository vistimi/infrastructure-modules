output "autoscaling_group_name" {
  value       = module.ec2-asg.autoscaling_group_name
  description = "The name of the Auto Scaling Group"
}

output "autoscaling_group_arn" {
  value       = module.ec2-asg.autoscaling_group_arn
  description = "ARN of the Auto Scaling Group"
}

output "alb_dns_name" {
  value       = module.ec2-asg.alb_dns_name
  description = "The domain name of the load balancer"
}

output "alb_security_group_id" {
  value       = module.ec2-asg.alb_security_group_id
  description = "The ID of the security group"
}