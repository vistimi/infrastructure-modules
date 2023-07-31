data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  region_name = data.aws_region.current.name
  account_id  = data.aws_caller_identity.current.account_id
}

module "aws_level" {
  source = "../../aws/iam/level"

  levels                    = var.aws.levels
  groups                    = var.aws.groups
  statements                = var.aws.statements
  external_assume_role_arns = var.aws.external_assume_role_arns

  store_secrets = var.aws.store_secrets

  tags = var.aws.tags
}

resource "github_actions_variable" "example_variable" {
  for_each = { for repository in var.github.repositories : repository.name => {} }

  repository    = each.key
  variable_name = var.github.docker_action.key
  value         = var.github.docker_action.value
}

module "github_environments" {
  source = "../../github/environments"

  for_each = merge([
    for group_name, groups in module.aws_level.groups : merge({
      for user_name, value in groups.users : user_name => value.user if var.github.store_environment
    })
  ]...)

  name             = each.value.iam_user_name
  repository_names = [for repository in var.github.repositories : join("/", [repository.owner, repository.name])]
  variables = [
    { key = "AWS_ACCESS_KEY", value = each.value.iam_access_key_id },
    { key = "AWS_ACCOUNT_ID", value = local.account_id },
    { key = "AWS_PROFILE_NAME", value = each.value.iam_user_name },
    { key = "AWS_REGION_NAME", value = local.region_name },
  ]
  secrets = [
    { key = "AWS_SECRET_KEY", value = merge([
      for group_name, groups in module.aws_level.groups_sensitive : merge({
        for user_name, value in groups.users : user_name => value.user
      })
      ]...)[each.key].iam_access_key_secret
    }
  ]
}
