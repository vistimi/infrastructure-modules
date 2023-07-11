data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  dns_suffix = data.aws_partition.current.dns_suffix // amazonaws.com
  partition  = data.aws_partition.current.partition  // aws

  account_ids = distinct(compact(concat(var.account_ids, [local.account_id])))
}

data "aws_iam_policy_document" "this" {
  dynamic "statement" {
    for_each = var.statements

    content {
      actions   = statement.value["actions"]
      resources = statement.value["resources"]
      effect    = statement.value["effect"]

      # accounts
      dynamic "condition" {
        for_each = statement.value.scope == "accounts" ? { statement.value.scope = {} } : {}
        content {
          test     = "ForAnyValue:StringEquals"
          variable = "aws:SourceAccount"
          values   = local.account_ids
        }
      }

      # microservice
      dynamic "principals" {
        for_each = statement.value.scope == "microservice" && length(var.principals_services) > 0 ? { statement.value.scope = {} } : {}
        content {
          type        = "Service"
          identifiers = [for service in var.principals_services : "${service}.${local.dns_suffix}"]
        }
      }
      dynamic "condition" {
        for_each = statement.value.scope == "microservice" ? { statement.value.scope = {} } : {}
        content {
          test     = "ForAnyValue:StringEquals"
          variable = "aws:SourceVpce"
          values   = local.vpc_ids
        }
      }
    }
  }
}
