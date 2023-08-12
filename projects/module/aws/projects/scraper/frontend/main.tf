locals {
  config_vars = yamldecode(file("./config.yml"))
  name        = lower(join("-", compact([var.name_prefix, local.config_vars.project_name, local.config_vars.service_name, var.name_suffix])))
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
