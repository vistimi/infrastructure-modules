output "ecs" {
  value = {
    elb     = module.ecs.elb
    acm     = module.ecs.acm
    route53 = module.ecs.route53
    asg     = module.ecs.asg
    cluster = module.ecs.cluster
    service = module.ecs.service
  }
}

output "bucket_env" {
  value = one(values(module.bucket_env))
}
