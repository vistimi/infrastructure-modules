data "github_repository" "repo" {
  full_name = var.repository_name
}

resource "github_repository_environment" "repo_environment" {
  repository  = data.github_repository.repo.name
  environment = var.name
}

resource "github_actions_environment_secret" "environment" {

  for_each = { for secret in var.secrets : secret.key => sensitive(secret.value) }

  repository      = data.github_repository.repo.name
  environment     = github_repository_environment.repo_environment.environment
  secret_name     = each.key
  plaintext_value = each.value
}

resource "github_actions_environment_variable" "environment" {

  for_each = { for variable in var.variables : variable.key => variable.value }

  repository    = data.github_repository.repo.name
  environment   = github_repository_environment.repo_environment.environment
  variable_name = each.key
  value         = each.value
}
