module "microservice" {
  source = "../../../../module/aws/container/microservice"

  common_name = var.common_name
  common_tags = var.common_tags
  vpc         = var.microservice.vpc
  ecs         = var.microservice.ecs
  bucket_env  = var.microservice.bucket_env
}
