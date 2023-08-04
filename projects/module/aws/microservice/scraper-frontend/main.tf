locals {
  config_vars = yamldecode(file("./config.yml"))
  name        = lower(join("-", ["${local.config_vars.name}", "${var.name_suffix}"]))
}

module "microservice" {
  source = "../../../../../module/aws/container/microservice"

  name       = local.name
  tags       = var.tags
  vpc        = var.vpc
  route53    = var.microservice.route53
  ecs        = var.microservice.ecs
  bucket_env = var.microservice.bucket_env
  iam        = var.microservice.iam
}
