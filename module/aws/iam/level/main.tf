data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  region_name = data.aws_region.current.name
  tags        = merge(var.tags, { RootAccountId = data.aws_caller_identity.current.account_id, RootAccountArn = data.aws_caller_identity.current.arn, Region = local.region_name })
  name        = join("-", [for level in var.levels : level.value])
}

data "aws_iam_policy_document" "level" {

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

module "iam_policy_level" {
  source = "terraform-aws-modules/iam/aws//modules/iam-policy"

  count = length(var.statements) > 0 ? 1 : 0

  name        = "${local.name}-level-scope"
  path        = "/"
  description = "Group policy"

  policy = data.aws_iam_policy_document.level[count.index].json

  tags = local.tags
}

resource "aws_iam_group_policy_attachment" "external" {
  for_each = { for key, group in module.groups : key => group if length(module.iam_policy_level) == 1 }

  group      = each.value.group.group_name
  policy_arn = element(module.iam_policy_level[*].arn, 0)
}

module "groups" {
  source = "../group"

  for_each = { for key, group in var.groups : key => group }

  name   = each.key
  levels = var.levels

  force_destroy = each.value.force_destroy
  pw_length     = each.value.pw_length
  users         = each.value.users
  statements    = each.value.statements

  external_assume_role_arns = var.external_assume_role_arns
  store_secrets             = var.store_secrets

  tags = var.tags
}
