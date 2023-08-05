data "aws_iam_policy_document" "this" {
  dynamic "statement" {
    for_each = var.statements

    content {
      actions   = statement.value.actions
      resources = statement.value.resources
      effect    = statement.value.effect

      principals {
        type        = "*"
        identifiers = ["*"]
      }

      # mfa
      dynamic "condition" {
        for_each = var.requires_mfa ? { "${var.scope}" = {} } : {}
        content {
          test     = "Bool"
          variable = "aws:MultiFactorAuthPresent"
          values   = ["true"]
        }
      }
      dynamic "condition" {
        for_each = var.requires_mfa ? { "${var.scope}" = {} } : {}
        content {
          test     = "NumericLessThan"
          variable = "aws:MultiFactorAuthAge"
          values   = [var.mfa_age]
        }
      }

      # accounts
      dynamic "condition" {
        for_each = contains(["accounts"], var.scope) ? { "${var.scope}" = {} } : {}
        content {
          test     = "ForAnyValue:StringEquals"
          variable = "aws:SourceAccount"
          values   = local.account_ids
        }
      }

      # vpcs
      dynamic "condition" {
        for_each = contains(["vpcs"], var.scope) && length(var.vpc_ids) > 0 ? { "${var.scope}" = {} } : {}
        content {
          test     = "ForAnyValue:StringEquals"
          variable = "aws:SourceVpc"
          values   = var.vpc_ids
        }
      }

      # groups
      dynamic "condition" {
        for_each = contains(["groups"], var.scope) && length(var.group_names) > 0 ? { "${var.scope}" = {} } : {}
        content {
          test     = "ForAnyValue:StringEquals"
          variable = "aws:PrincipalArn"
          values   = [for group_name in var.group_names : "arn:aws:iam::${local.account_id}:group/${group_name}"]
        }
      }

      # users
      dynamic "condition" {
        for_each = contains(["users"], var.scope) && length(var.user_names) > 0 ? { "${var.scope}" = {} } : {}
        content {
          test     = "ForAnyValue:StringEquals"
          variable = "aws:PrincipalArn"
          values   = [for user_name in var.user_names : "arn:aws:iam::${local.account_id}:user/${user_name}"]
        }
      }
    }
  }
}
