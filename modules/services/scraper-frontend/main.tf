module "microservice" {
  source = "../../components/microservice"

  common_name = var.common_name
  common_tags = var.common_tags
  vpc         = var.vpc

  ecs        = var.ecs
  ecr        = var.ecr
  bucket_env = var.bucket_env
}
