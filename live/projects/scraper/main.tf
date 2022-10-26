terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"

  backend "s3" {
    bucket         = "terraform-state-backend-storage"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-backend-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region
}

locals {
  common_tags = { Region : var.region, Project : var.project_name, Environment : var.environment_name }
}

# VPC
module "vpc" {
  source = "../../../modules/vpc"

  region           = var.region
  project_name     = var.project_name
  environment_name = var.environment_name
  common_tags      = local.common_tags
  vpc_cidr_ipv4    = var.vpc_cidr_ipv4
}

# # Backend
# module "scraper_backend" {
#   source = "modules/services/scraper-backend"

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
#   user_data_args = merge(
#     var.user_data_args,
#     {
#       bucket_name_mount_helper = "global-mount-helper"
#       bucket_name_mongodb      = "${var.project_name}-${var.environment_name}-mongodb"
#       bucket_name_pictures     = "${var.project_name}-${var.environment_name}-pictures"
#       aws_region               = var.AWS_REGION,
#       aws_profile              = var.AWS_PROFILE,
#       aws_access_key           = var.AWS_ACCESS_KEY,
#       aws_secret_key           = var.AWS_SECRET_KEY,
#       mongodb_version         = var.mongodb_version
#     }
#   )
# }

