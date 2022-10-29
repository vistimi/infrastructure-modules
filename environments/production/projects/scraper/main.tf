locals {
  common_tags = { Region : var.region, Project : var.project_name, Environment : var.environment_name }
}

# VPC
module "vpc" {
  source = "../../../../modules/vpc"

  region           = var.region
  project_name     = var.project_name
  environment_name = var.environment_name
  common_tags      = local.common_tags
  vpc_cidr_ipv4    = var.vpc_cidr_ipv4
}

# # Backend
# module "scraper_backend" {
#   source = "../../../modules/services/scraper-backend"

#   vpc_id             = module.vpc.id
#   public_subnet_ids  = module.vpc.public_subnets_ids
#   private_subnet_ids = module.vpc.public_subnets_ids
#   common_tags        = local.common_tags
#   cluster_name       = var.cluster_name
#   server_port        = var.server_port
#   health_check_path  = var.health_check_path
#   ami_name           = var.ami_name
#   instance_type      = var.instance_type
#   user_data_path     = var.user_data_path
#   user_data_args = {
#       bucket_name_mount_helper = var.bucket_name_mount_helper
#       bucket_name_mongodb      = "${var.project_name}-${var.environment_name}-mongodb"
#       bucket_name_pictures     = "${var.project_name}-${var.environment_name}-pictures"
#       mongodb_version          = var.mongodb_version
#       aws_region               = var.aws_region,
#       aws_profile              = var.aws_profile,
#       aws_access_key           = var.aws_access_key,
#       aws_secret_key           = var.aws_secret_key,
#     }
# }

# # ECS
# module "ecs" {
#   source = "../../../../modules/containers/cluster"

#   region                    = var.region
#   project_name              = var.project_name
#   environment_name          = var.environment_name
#   common_tags               = var.common_tags
#   auto_scaling_group_arn    = var.auto_scaling_group_arn
#   maximum_scaling_step_size = var.maximum_scaling_step_size
#   minimum_scaling_step_size = var.minimum_scaling_step_size
#   target_capacity           = var.target_capacity
# }