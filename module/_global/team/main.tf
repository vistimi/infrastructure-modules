data "aws_region" "current" {}

module "aws_team" {
  source = "../../aws/iam/team"

  name = var.name

  admins        = var.aws.admins
  devs          = var.aws.devs
  machines      = var.aws.machines
  resources     = var.aws.resources
  store_secrets = var.aws.store_secrets

  tags = var.aws.tags
}

module "github_environments" {
  source = "../../github/environments"

  for_each = { for name, user in module.aws_team.users : name => {
    iam_access_key_id  = user.iam_access_key_id
    iam_user_unique_id = user.iam_user_unique_id
    iam_user_name      = user.iam_user_name
  } if var.github.store_environment }

  name             = each.value.iam_user_name
  repository_names = var.github.repository_names
  variables = [
    { key = "AWS_ACCESS_KEY", value = each.value.iam_access_key_id },
    { key = "AWS_ACCOUNT_ID", value = each.value.iam_user_unique_id },
    { key = "AWS_PROFILE_NAME", value = each.value.iam_user_name },
    { key = "AWS_REGION_NAME", value = data.aws_region.current.name },
  ]
  secrets = [
    { key = "AWS_SECRET_KEY", value = sensitive(module.aws_team.users_sensitive[each.key].iam_access_key_secret) }
  ]
}
