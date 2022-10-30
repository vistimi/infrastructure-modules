locals {
  common_tags = { Region : var.region, Project : var.project_name, Environment : var.environment_name }
}

# VPC
module "vpc" {
  source = "../../modules/vpc"

  region           = var.region
  project_name     = var.project_name
  environment_name = var.environment_name
  common_tags      = local.common_tags
  vpc_cidr_ipv4    = var.vpc_cidr_ipv4
}
