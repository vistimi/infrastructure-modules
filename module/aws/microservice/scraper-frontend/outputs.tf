output "microservice" {
  value = {
    ecs        = module.microservice.ecs
    bucket_env = module.microservice.bucket_env
  }
}
