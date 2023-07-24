data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  region_name = data.aws_region.current.name
  tags        = merge(var.tags, { title(var.level_key) = var.level_value, RootAccountId = data.aws_caller_identity.current.account_id, RootAccountArn = data.aws_caller_identity.current.arn, Region = local.region_name })
  name        = join("-", concat([for level in var.levels : level.value], [var.level_value]))
}

data "aws_iam_policy_document" "level" {
  for_each = length(var.statements) > 0 ? { var.level_key = {} } : {}

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

module "iam_policy_level" {
  source = "terraform-aws-modules/iam/aws//modules/iam-policy"

  for_each = length(var.statements) > 0 ? { var.level_key = {} } : {}

  name        = local.name
  path        = "/"
  description = "Group policy"

  policy = data.aws_iam_policy_document.level[each.key].json

  tags = local.tags
}


module "resource_mutable" {
  source = "../group"

  for_each = { for key, group in var.groups : key => group if key == "resource-mutable" }

  group_key = each.key
  levels    = concat(var.levels, [{ key = var.level_key, value = var.level_value }])

  force_destroy = each.value.force_destroy
  admin         = true
  poweruser     = true
  readonly      = false
  pw_length     = each.value.pw_length
  users         = each.value.users
  statements    = each.value.statements

  external_assume_role_arns = concat(var.external_assume_role_arns, [for policy in module.iam_policy_level : policy.arn])
  store_secrets             = var.store_secrets

  tags = var.tags
}

module "resource_immutable" {
  source = "../group"

  for_each = { for key, group in var.groups : key => group if key == "resource-immutable" }

  group_key = each.key
  levels    = concat(var.levels, [{ key = var.level_key, value = var.level_value }])

  force_destroy = each.value.force_destroy
  admin         = true
  poweruser     = true
  readonly      = true
  pw_length     = each.value.pw_length
  users         = each.value.users
  statements    = each.value.statements

  external_assume_role_arns = concat(var.external_assume_role_arns, [for policy in module.iam_policy_level : policy.arn])
  store_secrets             = var.store_secrets

  tags = var.tags
}

module "machine" {
  source = "../group"

  for_each = { for key, group in var.groups : key => group if key == "machine" }

  group_key = each.key
  levels    = concat(var.levels, [{ key = var.level_key, value = var.level_value }])

  force_destroy = each.value.force_destroy
  admin         = true
  poweruser     = true
  readonly      = false
  pw_length     = each.value.pw_length
  users         = each.value.users
  statements    = each.value.statements

  external_assume_role_arns = concat(
    var.external_assume_role_arns,
    [for policy in module.iam_policy_level : policy.arn],
    [for group in module.resource_mutable : group.role.poweruser_iam_role_arn],
    [for group in module.resource_immutable : group.role.readonly_iam_role_arn]
  )
  store_secrets = var.store_secrets

  tags = var.tags
}


module "dev" {
  source = "../group"

  for_each = { for key, group in var.groups : key => group if key == "dev" }

  group_key = each.key
  levels    = concat(var.levels, [{ key = var.level_key, value = var.level_value }])

  force_destroy = each.value.force_destroy
  admin         = true
  poweruser     = true
  readonly      = false
  pw_length     = each.value.pw_length
  users         = each.value.users
  statements    = each.value.statements

  external_assume_role_arns = concat(
    var.external_assume_role_arns,
    [for policy in module.iam_policy_level : policy.arn],
    [for group in module.resource_mutable : group.role.poweruser_iam_role_arn],
    [for group in module.resource_immutable : group.role.readonly_iam_role_arn]
  )
  store_secrets = var.store_secrets

  tags = var.tags
}

module "admin" {
  source = "../group"

  for_each = { for key, group in var.groups : key => group if key == "admin" }

  group_key = each.key
  levels    = concat(var.levels, [{ key = var.level_key, value = var.level_value }])

  force_destroy = each.value.force_destroy
  admin         = true
  poweruser     = false
  readonly      = false
  pw_length     = each.value.pw_length
  users         = each.value.users
  statements    = each.value.statements

  external_assume_role_arns = concat(
    var.external_assume_role_arns,
    [for policy in module.iam_policy_level : policy.arn],
    [for group in module.resource_mutable : group.role.admin_iam_role_arn],
    [for group in module.resource_immutable : group.role.admin_iam_role_arn],
    [for group in module.machine : group.role.admin_iam_role_arn],
    [for group in module.dev : group.role.admin_iam_role_arn]
  )
  store_secrets = var.store_secrets

  tags = var.tags
}
