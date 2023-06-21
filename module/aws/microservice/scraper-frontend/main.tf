module "microservice" {
  source = "../../../../module/aws/container/microservice"

  common_name = var.common_name
  common_tags = var.common_tags
  vpc         = var.vpc

  ecs = var.ecs
  bucket_env = var.bucket_env
}
