output "aws" {
  value = {
    users = module.aws_team.users
    # users_sensitive = module.aws_team.users_sensitive
    accounts       = module.aws_team.accounts
    secret_manager = module.aws_team.secret_manager
    roles          = module.aws_team.roles
    groups         = module.aws_team.groups
  }
}

output "github" {
  value = module.github_environments
}
