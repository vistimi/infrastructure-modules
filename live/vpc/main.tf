module "vpc" {
  source = "../../modules/vpc"

  region           = var.region
  project_name     = var.project_name
  environment_name = var.environment_name
  common_tags      = var.common_tags
  vpc_cidr_ipv4    = var.vpc_cidr_ipv4
}

