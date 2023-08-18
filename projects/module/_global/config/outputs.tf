output "organization_variables" {
  value = github_actions_organization_variable.organization_variables
}

output "organization_secrets" {
  value     = github_actions_organization_secret.organization_secrets
  sensitive = true
}

output "repository_variables" {
  value = github_actions_variable.repository_variables
}

output "repository_secrets" {
  value     = github_actions_secret.repository_secrets
  sensitive = true
}
