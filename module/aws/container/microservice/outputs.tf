output "ecs" {
  value = {
    elb     = module.ecs.elb
    asg     = module.ecs.asg
    cluster = module.ecs.cluster
    service = module.ecs.service
  }
}

output "ecr" {
  value = module.ecr
}

output "bucket_env" {
  value = module.bucket_env
}
