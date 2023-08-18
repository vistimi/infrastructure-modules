output "aws" {
  value = {
    groups = module.aws_level.groups
  }
}

output "group_user_project_statements" {
  value = module.group_user_project_statements
}

output "aws_sensitive" {
  value = {
    groups = sensitive(module.aws_level.groups_sensitive)
  }
  sensitive = true
}

output "github_variables" {
  value = {
    organization_variables = try(one(module.github_variables).organization_variables, null)
    repository_variables   = try(one(module.github_variables).repository_variables, null)
    environment_variables  = try(one(module.github_variables).environment_variables, null)
  }
}

output "github_secrets" {
  value = {
    organization_secrets = try(one(module.github_variables).organization_secrets, null)
    repository_secrets   = try(one(module.github_variables).repository_secrets, null)
    environment_secrets  = try(one(module.github_variables).environment_secrets, null)
  }
  sensitive = true
}
