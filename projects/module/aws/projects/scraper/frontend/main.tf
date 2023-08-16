locals {
  microservice_config_vars = yamldecode(file("../../microservice.yml"))
  # repository_config_vars   = yamldecode(file("./repository.yml"))
}

module "microservice" {
  source = "../../../../../../module/aws/container/microservice"

  name       = "${var.name_prefix}-scraper-fe-${var.name_suffix}"
  tags       = var.tags
  vpc        = var.vpc
  route53    = var.microservice.route53
  ecs        = var.microservice.ecs
  bucket_env = merge(var.microservice.bucket_env, { name = local.microservice_config_vars.bucket_env_name })
  iam        = var.microservice.iam
}
