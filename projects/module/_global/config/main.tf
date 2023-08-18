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
