# https://registry.terraform.io/modules/terraform-aws-modules/iam/aws/latest

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  region_name = data.aws_region.current.name
  tags        = merge(var.tags, { RootAccountId = data.aws_caller_identity.current.account_id, RootAccountArn = data.aws_caller_identity.current.arn, Region = local.region_name })
}

module "level_user" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "5.28.0"

  name          = var.name
  force_destroy = false

  create_iam_access_key = true

  password_reset_required = false

  tags = merge(local.tags, { Account = var.name })
}

module "secret_manager" {
  source = "../../secret/manager"

  names = ["team/${var.name}/user/${module.level_user.iam_user_name}"]
  secrets = [
    { key = "AWS_SECRET_KEY", value = sensitive(module.level_user.iam_access_key_secret) },
    { key = "AWS_ACCESS_KEY", value = module.level_user.iam_access_key_id },
    { key = "AWS_ACCOUNT_ID", value = module.level_user.iam_user_unique_id },
    { key = "AWS_PROFILE_NAME", value = module.level_user.iam_user_name },
    { key = "AWS_REGION_NAME", value = local.region_name },
  ]

  tags = merge(local.tags, { Account = module.level_user.iam_user_name })
}

# TODO: add mfa

module "level_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-roles"
  version = "5.28.0"

  trusted_role_arns = ["*"]

  create_admin_role = true
  admin_role_name   = "${var.name}-admin"
}

module "level_group" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-group-with-assumable-roles-policy"
  version = "5.28.0"

  name = var.name

  assumable_roles = [module.level_role.admin_iam_role_arn]

  group_users = module.level_user.iam_user_name

  tags = merge(local.tags, { Role = "admin" })
}