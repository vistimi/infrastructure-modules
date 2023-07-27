# https://registry.terraform.io/modules/terraform-aws-modules/iam/aws/latest

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  region_name = data.aws_region.current.name
  tags        = merge(var.tags, { Group = var.group_key, Role = var.group_key, RootAccountId = data.aws_caller_identity.current.account_id, RootAccountArn = data.aws_caller_identity.current.arn, Region = local.region_name })
  name        = join("-", concat([for level in var.levels : level.value], [var.group_key]))
}

module "users" {
  source = "../user"

  for_each = { for user in var.users : user.name => user }

  name          = each.key
  levels        = concat(var.levels, [{ key = "group", value = var.group_key }])
  statements    = each.value.statements
  pw_length     = var.pw_length
  store_secrets = var.store_secrets

  tags = local.tags
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

  create_poweruser_role = true //var.poweruser
  poweruser_role_name   = join("-", [local.name, "poweruser"])

  create_readonly_role       = var.readonly
  readonly_role_requires_mfa = false
  readonly_role_name         = join("-", [local.name, "readonly"])
}

#---------------
#     Groups
#---------------
module "group" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-group-with-assumable-roles-policy"
  version = "5.28.0"

  name = local.name

  assumable_roles = concat(compact([module.group_role.poweruser_iam_role_arn]), var.external_assume_role_arns)

  group_users = [for user in module.users : user.user.iam_user_name]

  tags = local.tags
}

data "aws_iam_policy_document" "group" {

  count = length(var.statements) > 0 ? 1 : 0

  dynamic "statement" {
    for_each = var.statements

    content {
      sid       = statement.value.sid
      actions   = statement.value.actions
      resources = statement.value.resources
      effect    = statement.value.effect

      dynamic "condition" {
        for_each = statement.value.conditions
        content {
          test     = condition.value.test
          variable = condition.value.variable
          values   = condition.value.values
        }
      }
    }
  }
}

module "group_policy" {
  source = "terraform-aws-modules/iam/aws//modules/iam-group-with-policies"

  count = length(var.statements) > 0 ? 1 : 0

  name = module.group.group_name

  attach_iam_self_management_policy = var.attach_iam_self_management_policy

  create_group = false

  custom_group_policies = [
    {
      name   = "${local.name}-group-scope"
      policy = data.aws_iam_policy_document.group[count.index].json
    },
  ]
}
