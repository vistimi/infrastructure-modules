data "aws_region" "current" {}

module "aws_level" {
  source = "../../aws/iam/level"

  level_key                 = var.aws.level_key
  level_value               = var.aws.level_value
  levels                    = var.aws.levels
  groups                    = var.aws.groups
  statements                = var.aws.statements
  external_assume_role_arns = var.aws.external_assume_role_arns

  store_secrets = var.aws.store_secrets

  tags = var.aws.tags
}

module "github_environments" {
  source = "../../github/environments"

  for_each = merge([
    for group_key, groups in module.aws_level.groups : merge({
      for user_name, user in groups.users : user_name => user if var.github.store_environment
    })
  ]...)

  name             = each.value.iam_user_name
  repository_names = var.github.repository_names
  variables = [
    { key = "AWS_ACCESS_KEY", value = each.value.iam_access_key_id },
    { key = "AWS_ACCOUNT_ID", value = each.value.iam_user_unique_id },
    { key = "AWS_PROFILE_NAME", value = each.value.iam_user_name },
    { key = "AWS_REGION_NAME", value = data.aws_region.current.name },
  ]
  secrets = [
    { key = "AWS_SECRET_KEY", value = merge([
      for group_key, groups in module.aws_level.groups : merge({
        for user_name, user_sensitive in groups.users_sensitive : user_name => user_sensitive
      })
      ]...)[each.key].iam_access_key_secret
    }
  ]
}
