module "environments" {
  source = "./environment"

  for_each = { for name in var.repository_names : name => {} }

  repository_name = each.key

  name      = var.name
  variables = var.variables
  secrets   = var.secrets
}
