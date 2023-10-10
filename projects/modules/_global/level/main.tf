data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  region_name = data.aws_region.current.name
  account_id  = data.aws_caller_identity.current.account_id
}

module "group_user_project_statements" {
  source = "../../aws/iam/statements/project"

  for_each = merge([
    for key, value in var.aws.groups : merge([
      for user in value.users : {
        "${key}-${user.name}" = {
          project_names = value.project_names
          user_name     = user.name
        }
      }]...
    ) if length(value.project_names) > 0
  ]...)

  name_prefix   = var.name_prefix
  root_path     = "../../../.."
  project_names = each.value.project_names
  user_name     = each.value.user_name
}

module "aws_level" {
  source = "../../../../modules/aws/iam/level"

  levels = var.aws.levels
  groups = { for key, value in var.aws.groups : key => {
    force_destroy = value.force_destroy
    pw_length     = value.pw_length
    users = [for user in value.users : merge(user, {
      statements = concat(try(user.statements, []), try(module.group_user_project_statements["${key}-${user.name}"].statements, []))
      })
    ]
    statements = value.statements
    }
  }
  statements                = var.aws.statements
  external_assume_role_arns = var.aws.external_assume_role_arns

  store_secrets = var.aws.store_secrets

  tags = var.aws.tags
}

module "github_variables" {
  source = "../../../../modules/github/variables"

  for_each = var.github.store_environment ? { "${var.name_prefix}" = {} } : {}

  environments = flatten([
    for group_name, group in module.aws_level.groups : [
      for user_name, value in group.users : {
        name     = user_name
        accesses = var.github.accesses
        variables = [
          { key = "AWS_ACCESS_KEY", value = value.user.iam_access_key_id },
          { key = "AWS_ACCOUNT_ID", value = local.account_id },
          { key = "AWS_PROFILE_NAME", value = value.user.iam_user_name },
          { key = "AWS_REGION_NAME", value = local.region_name },
        ]
        secrets = [{ key = "AWS_SECRET_KEY", value = sensitive(module.aws_level.groups_sensitive[group_name].users[user_name].user.iam_access_key_secret) }]
      }
    ]
  ])

  repositories = [for repository in var.github.repositories : {
    accesses  = var.github.accesses
    variables = repository.variables
  }]
}
