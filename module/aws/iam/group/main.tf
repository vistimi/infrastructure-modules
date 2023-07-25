# https://registry.terraform.io/modules/terraform-aws-modules/iam/aws/latest

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  region_name = data.aws_region.current.name
  tags        = merge(var.tags, { Group = var.group_key, Role = var.group_key, RootAccountId = data.aws_caller_identity.current.account_id, RootAccountArn = data.aws_caller_identity.current.arn, Region = local.region_name })
  name        = join("-", concat([for level in var.levels : level.value], [var.group_key]))
}

data "aws_iam_policy_document" "users" {
  for_each = { for user in var.users : user.name => user.statements if length(user.statements) > 0 }

  dynamic "statement" {
    for_each = each.value

    content {
      sid       = statement.value.sid
      actions   = statement.value.actions
      resources = statement.value.resources
      effect    = statement.value.effect
    }
  }
}

resource "aws_iam_policy" "users" {
  for_each = { for user_name, policy_document_user in data.aws_iam_policy_document.users : user_name => policy_document_user }

  name        = "${local.name}-${each.key}-user-scope"
  path        = "/"
  description = "User policy"

  policy = each.value.json

  tags = local.tags
}

resource "aws_iam_user_policy_attachment" "test-attach" {
  for_each = { for user_name, policy_user in aws_iam_policy.users : user_name => policy_user }

  user       = module.users[each.key].iam_user_name
  policy_arn = each.value.arn
}

module "users" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "5.28.0"

  for_each = { for user in var.users : user.name => {} }

  name          = join("-", [local.name, each.key])
  force_destroy = var.force_destroy

  create_iam_access_key = true

  password_length         = var.pw_length
  password_reset_required = false

  tags = local.tags
}

// TODO: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_virtual_mfa_device

#---------------
#     Secrets
#---------------
module "secret_manager" {
  source = "../../secret/manager"

  for_each = { for key, user in module.users : key => user if var.store_secrets }

  name = join("/", concat([for level in var.levels : "${level.key}/${level.value}"], ["group/${var.group_key}", "user/${each.value.iam_user_name}"]))
  secrets = [
    { key = "AWS_SECRET_KEY", value = sensitive(each.value.iam_access_key_secret) },
    { key = "AWS_ACCESS_KEY", value = each.value.iam_access_key_id },
    { key = "AWS_ACCOUNT_ID", value = each.value.iam_user_unique_id },
    { key = "AWS_PROFILE_NAME", value = each.value.iam_user_name },
    { key = "AWS_REGION_NAME", value = local.region_name },
    { key = "AWS_ACCOUNT_PASSWORD", value = each.value.iam_user_login_profile_password },
  ]

  tags = merge(local.tags, { Account = each.value.iam_user_name })
}

#------------------
#     Accounts
#------------------
module "accounts" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-account"
  version = "5.28.0"

  for_each = { for key, user in module.users : key => user }

  account_alias = lower(each.value.iam_user_name)

  minimum_password_length      = var.pw_length
  require_lowercase_characters = true
  require_uppercase_characters = true
  require_numbers              = true
  require_symbols              = true
}

#---------------
#     Roles
#---------------
module "group_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-roles"
  version = "5.28.0"

  trusted_role_arns = ["*"]

  create_admin_role = var.admin
  admin_role_name   = join("-", [local.name, "admin"])

  create_poweruser_role = var.poweruser
  poweruser_role_name   = join("-", [local.name, "poweruser"])

  create_readonly_role       = var.readonly
  readonly_role_requires_mfa = false
  readonly_role_name         = join("-", [local.name, "readonly"])
}

#---------------
#     Groups
#---------------
data "aws_iam_policy_document" "group" {

  count = length(var.statements) > 0 ? 1 : 0

  dynamic "statement" {
    for_each = var.statements

    content {
      sid       = statement.value.sid
      actions   = statement.value.actions
      resources = statement.value.resources
      effect    = statement.value.effect
    }
  }
}

module "group" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-group-with-assumable-roles-policy"
  version = "5.28.0"

  name = local.name

  assumable_roles = concat([module.group_role.poweruser_iam_role_arn], var.external_assume_role_arns)

  group_users = [for user in module.users : user.iam_user_name]

  tags = local.tags
}

module "group_policy" {
  source = "terraform-aws-modules/iam/aws//modules/iam-group-with-policies"

  count = length(var.statements) > 0 ? 1 : 0

  name = module.group.group_name

  create_group = false

  custom_group_policies = [
    {
      name   = "${local.name}-group-scope"
      policy = data.aws_iam_policy_document.group[count.index].json
    },
  ]
}
