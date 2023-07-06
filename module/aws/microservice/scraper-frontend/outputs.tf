output "microservice" {
  value = {
    ecs        = module.microservice.ecs
    vpc        = module.microservice.vpc
    bucket_env = module.microservice.bucket_env
  }
}
