# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION BLOCKS
# ---------------------------------------------------------------------------------------------------------------------
locals {
  # # Automatically load account-level variables
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  # Extract the variables we need for easy access
  aws_account_id        = local.account_vars.locals.aws_account_id
  aws_account_region    = local.account_vars.locals.aws_account_region
}

# Generate a Terraform and AWS version block
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
      }
      required_version = ">= 1.2.0"
    }
EOF
}

# Generate an AWS provider block
generate "provider" {
  path      = "provider_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.aws_account_region}"
  
  # Only these AWS Account IDs may be operated on by this template
  allowed_account_ids = ["${local.aws_account_id}"]
}
EOF
}
