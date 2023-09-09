output "ecs" {
  value = one(values(module.ecs))
}

output "eks" {
  value = one(values(module.eks))
}

output "bucket_env" {
  value = one(values(module.bucket_env))
}
