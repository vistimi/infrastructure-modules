output "secrets" {
  value = {
    for name, secret in github_actions_environment_secret.environment : name => {
      created_at = secret.created_at
      updated_at = secret.updated_at
    }
  }
}

output "variables" {
  value = {
    for name, variable in github_actions_environment_variable.environment : name => {
      created_at = variable.created_at
      updated_at = variable.updated_at
    }
  }
}
