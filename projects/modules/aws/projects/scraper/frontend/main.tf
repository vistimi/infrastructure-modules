locals {
  microservice_config_vars = yamldecode(file("../../microservice.yml"))
  # repository_config_vars   = yamldecode(file("./repository.yml"))
}

module "microservice" {
  source = "../../../../../../modules/aws/container/microservice"

  name       = "${var.name_prefix}-sp-fe-${var.name_suffix}"
  vpc        = var.vpc
  route53    = var.microservice.route53
  container  = var.microservice.container
  bucket_env = var.microservice.bucket_env
  iam        = var.microservice.iam

  tags = var.tags
}
