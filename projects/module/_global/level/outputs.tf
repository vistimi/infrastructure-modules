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

output "github" {
  value = module.github_environments
}
