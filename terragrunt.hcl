# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION BLOCKS
# ---------------------------------------------------------------------------------------------------------------------
locals {
  aws_account_vars   = read_terragrunt_config(find_in_parent_folders("aws_account_override.hcl"))
  aws_account_id     = local.aws_account_vars.locals.aws_account_id
  aws_account_region = local.aws_account_vars.locals.aws_account_region
}

# Generate version block
generate "versions" {
  path      = "version_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.1"
    }
  }
  required_version = ">= 1.4.0"
}
EOF
}

# TODO: add ecr account for private repos
# Generate provider block
generate "provider" {
  path      = "provider_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.aws_account_region}"
  allowed_account_ids = ["${local.aws_account_id}"]
}
EOF
}
