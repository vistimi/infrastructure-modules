output "environments" {
  value = {
    for name, environment in module.environments : name => {
      secrets   = environment.secrets
      variables = environment.variables
    }
  }
}
