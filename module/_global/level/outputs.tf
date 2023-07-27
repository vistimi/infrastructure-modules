output "aws" {
  value = {
    groups = module.aws_level.groups
  }
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
