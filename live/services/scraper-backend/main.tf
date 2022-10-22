locals {
  region             = var.zone
  service            = "scraper-backend"
}

provider "aws" {
  region = local.region
}

module "scraper_backend" {
  source        = "modules/services/scraper-backend"
  
  # tags = local.common_tags
  cluster_name = local.ec2_cluster_name
  # all variables here
}
