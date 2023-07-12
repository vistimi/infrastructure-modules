data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

data "aws_vpc" "current" {
  id = var.tags[var.vpc_tag_name]

  lifecycle {
    postcondition {
      condition     = length(try(self.id, "")) > 0
      error_message = "no vpc found in policy_document with tags: ${jsonencode(var.tags)}"
    }
  }
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  vpc_id     = data.aws_vpc.current.id
  dns_suffix = data.aws_partition.current.dns_suffix // amazonaws.com
  partition  = data.aws_partition.current.partition  // aws

  account_ids = distinct(compact(concat(var.account_ids, [local.account_id])))
  vpc_ids     = distinct(compact(concat(var.vpc_ids, [local.vpc_id])))
}

resource "null_resource" "accounts" {
  for_each = var.scope == "accounts" ? { "${var.scope}" = {} } : {}
  lifecycle {
    precondition {
      condition     = length(local.account_ids) > 0
      error_message = "scope accounts must have at least one element in account_ids: ${jsonencode(local.account_ids)}"
    }
  }
}

resource "null_resource" "microservices" {
  for_each = var.scope == "microservices" ? { "${var.scope}" = {} } : {}
  lifecycle {
    precondition {
      condition     = length(local.vpc_ids) > 0
      error_message = "scope microservices must have at least one element in vpc_ids: ${jsonencode(local.vpc_ids)}"
    }
  }
}

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

      # accounts
      dynamic "condition" {
        for_each = contains(["microservices", "accounts"], var.scope) ? { "${var.scope}" = {} } : {}
        content {
          test     = "ForAnyValue:StringEquals"
          variable = "aws:SourceAccount"
          values   = local.account_ids
        }
      }

      # microservices
      dynamic "condition" {
        for_each = contains(["microservices"], var.scope) && length(local.vpc_ids) > 0 ? { "${var.scope}" = {} } : {}
        content {
          test     = "ForAnyValue:StringEquals"
          variable = "aws:SourceVpc"
          values   = local.vpc_ids
        }
      }
    }
  }
}
