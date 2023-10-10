output "microservice" {
  value = {
    ecs = module.microservice.ecs
    env = module.microservice.env
  }
}
