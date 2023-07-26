output "aws" {
  value = {
    for group_key, group in module.aws_level.groups : group_key => {
      users = group.users
      # users_sensitive = sensitive(group.users_sensitive)
      secret_manager = group.secret_manager
      accounts       = group.accounts
      role           = group.role
      group          = group.group
    }
  }
}

output "github" {
  value = module.github_environments
}
