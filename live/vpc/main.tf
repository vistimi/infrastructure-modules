terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"

  backend "s3" {
    bucket = "${var.backup_name}-storage"
    key    = "global/s3/terraform.tfstate"
    region = var.region

    # Replace this with your DynamoDB table name!
    dynamodb_table = "${var.backup_name}-locks"
    encrypt        = true
  }
}

module "vpc" {
  source = "../../modules/vpc"

  region           = var.region
  project_name     = var.project_name
  environment_name = var.environment_name
  common_tags      = var.common_tags
  vpc_cidr_ipv4    = var.vpc_cidr_ipv4
}