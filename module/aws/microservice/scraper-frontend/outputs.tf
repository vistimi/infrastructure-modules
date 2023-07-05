output "microservice" {
  value = {
    ecs        = module.microservice.ecs
    route53    = module.microservice.route53
    vpc        = module.microservice.vpc
    bucket_env = module.microservice.bucket_env
  }
}
