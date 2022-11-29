# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION BLOCKS
# ---------------------------------------------------------------------------------------------------------------------
locals {
  account_vars       = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  aws_account_id     = local.account_vars.locals.aws_account_id
  aws_account_region = local.account_vars.locals.aws_account_region
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
      version = "~> 4.16"
    }
    github = {
      source  = "integrations/github"
      version = "~> 4.0"
    }
  }
  required_version = ">= 1.2.0"
}
EOF
}

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
