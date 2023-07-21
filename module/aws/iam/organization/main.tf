# https://registry.terraform.io/modules/terraform-aws-modules/iam/aws/latest

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  region_name = data.aws_region.current.name
  tags        = merge(var.tags, { Organization = var.name })
}

module "organization_level" {
  source = "../level"

  name          = var.name
  store_secrets = var.store_secrets

  tags = local.tags
}

provider "aws" {
  alias = "organization"

  region     = local.region_name
  access_key = module.organization_level.user.iam_access_key_id
  secret_key = module.organization_level.user.iam_access_key_secret
}

#----------------
#   Team base
#---------------

module "team_base" {
  source   = "../team"
  provider = aws.organization

  name      = "${var.name}-base"
  resources = [{ name = "repositories", mutable = false }, { name = "dns", mutable = true }]

  store_secrets = var.store_secrets

  tags = local.tags
}

#----------------
#   Teams
#---------------

module "teams" {
  source   = "../team"
  provider = aws.organization

  for_each = { for team in var.teams : team.name => team }

  name      = "${var.name}-${each.key}"
  admins    = each.values.admins
  devs      = each.values.devs
  machines  = each.values.machines
  resources = each.values.resources

  external_assume_role_arns = [module.team_base.roles.resource-mutable.readonly_iam_role_arn, module.team_base.roles.resource-mutable.poweruser_iam_role_arn]

  store_secrets = var.store_secrets

  tags = local.tags
}
