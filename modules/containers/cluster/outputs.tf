output "autoscaling_capacity_providers" {
  value       = module.ecs.autoscaling_capacity_providers
  description = "Map of autoscaling capacity providers created and their attributes"
}

output "cluster_arn" {
  value       = module.ecs.cluster_arn
  description = "ARN that identifies the cluster"
}

output "cluster_id" {
  value       = module.ecs.cluster_id
  description = "ID that identifies the cluster"
}

output "cluster_name" {
  value       = module.ecs.cluster_name
  description = "Name that identifies the cluster"
}
	