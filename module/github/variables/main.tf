#--------------
#     ORG
#--------------
resource "github_actions_organization_variable" "organization_variables" {
  for_each = { for variable in var.organization.variables : variable.key => variable.value }

  variable_name = each.key
  visibility    = "all"
  value         = each.value
}

resource "github_actions_organization_secret" "organization_secrets" {
  for_each = { for secret in var.organization.secrets : secret.key => sensitive(secret.value) }

  secret_name     = each.key
  visibility      = "all"
  plaintext_value = sensitive(each.value)
}

#--------------
#     REPO
#--------------
resource "github_actions_variable" "repository_variables" {
  for_each = {
    for obj in flatten([for repository in var.repositories : [for access in repository.accesses : [for variable in repository.variables : {
      key      = "${access.owner}-${access.name}-${variable.key}"
      access   = access
      variable = variable
    }]]]) : obj.key => { access = obj.access, variable = obj.variable }
  }

  repository    = each.value.access.name
  variable_name = each.value.variable.key
  value         = each.value.variable.value
}

resource "github_actions_secret" "repository_secrets" {
  for_each = {
    for obj in flatten([for repository in var.repositories : [for access in repository.accesses : [for secret in repository.secrets : {
      key    = "${access.owner}-${access.name}-${secret.key}"
      access = access
      secret = secret
    }]]]) : obj.key => { access = obj.access, secret = sensitive(obj.secret) }
  }

  repository      = each.value.access.name
  secret_name     = each.value.secret.key
  plaintext_value = sensitive(each.value.secret.value)
}

#--------------
#     ENV
#--------------
data "github_repository" "repo" {
  for_each = {
    for obj in flatten([for environment in var.environments : [for access in environment.accesses : {
      key              = "${environment.name}-${access.owner}-${access.name}"
      environment_name = environment.name
      access           = access
    }]]) : obj.key => { access = obj.access }
  }

  full_name = join("/", [each.value.access.owner, each.value.access.name])
}

resource "github_repository_environment" "repo_environments" {
  for_each = {
    for obj in flatten([for environment in var.environments : [for access in environment.accesses : {
      key              = "${environment.name}-${access.owner}-${access.name}"
      environment_name = environment.name
      access           = access
    }]]) : obj.key => { environment_name = obj.environment_name, access = obj.access }
  }

  repository  = data.github_repository.repo[each.key].name
  environment = each.value.environment_name
}

resource "github_actions_environment_variable" "environment_variables" {
  for_each = {
    for obj in flatten([for environment in var.environments : [for access in environment.accesses : [for variable in environment.variables : {
      key              = "${environment.name}-${access.owner}-${access.name}-${variable.key}"
      environment_name = environment.name
      access           = access
      variable         = variable
    }]]]) : obj.key => { environment_name = obj.environment_name, access = obj.access, variable = obj.variable }
  }

  repository    = data.github_repository.repo["${each.value.environment_name}-${each.value.access.owner}-${each.value.access.name}"].name
  environment   = github_repository_environment.repo_environments["${each.value.environment_name}-${each.value.access.owner}-${each.value.access.name}"].environment
  variable_name = each.value.variable.key
  value         = each.value.variable.value
}

resource "github_actions_environment_secret" "environment_secrets" {
  for_each = {
    for obj in flatten([for environment in var.environments : [for access in environment.accesses : [for secret in environment.secrets : {
      key              = "${environment.name}-${access.owner}-${access.name}-${secret.key}"
      environment_name = environment.name
      access           = access
      secret           = secret
    }]]]) : obj.key => { environment_name = obj.environment_name, access = obj.access, secret = sensitive(obj.secret) }
  }

  repository      = data.github_repository.repo["${each.value.environment_name}-${each.value.access.owner}-${each.value.access.name}"].name
  environment     = github_repository_environment.repo_environments["${each.value.environment_name}-${each.value.access.owner}-${each.value.access.name}"].environment
  secret_name     = each.value.secret.key
  plaintext_value = sensitive(each.value.secret.value)
}
