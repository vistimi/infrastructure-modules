# https://registry.terraform.io/modules/terraform-aws-modules/iam/aws/latest

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  region_name = data.aws_region.current.name
  tags        = merge(var.tags, { Group = var.name, Role = var.name, RootAccountId = data.aws_caller_identity.current.account_id, RootAccountArn = data.aws_caller_identity.current.arn, Region = local.region_name })
  name        = join("-", concat([for level in var.levels : level.value], [var.name]))
}

# TODO: add accounts with subusers (run with provider in another run)
module "users" {
  source = "../user"

  for_each = { for user in var.users : user.name => user }

  name          = each.key
  levels        = concat(var.levels, [{ key = "group", value = var.name }])
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

  # https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AdministratorAccess.html
  create_admin_role = false
  admin_role_name   = join("-", [local.name, "admin"])

  # https://docs.aws.amazon.com/aws-managed-policy/latest/reference/PowerUserAccess.html
  create_poweruser_role = false
  poweruser_role_name   = join("-", [local.name, "poweruser"])

  # https://docs.aws.amazon.com/aws-managed-policy/latest/reference/ReadOnlyAccess.html
  create_readonly_role       = false
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

  assumable_roles = coalescelist(var.external_assume_role_arns, ["*"])

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

  # https://github.com/terraform-aws-modules/terraform-aws-iam/blob/master/modules/iam-group-with-policies/policies.tf
  attach_iam_self_management_policy = false

  create_group = false

  custom_group_policies = [
    {
      name   = "${local.name}-group-scope"
      policy = data.aws_iam_policy_document.group[count.index].json
    },
  ]
}
