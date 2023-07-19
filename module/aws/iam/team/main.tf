module "repository" {
  source = "terraform-aws-modules/iam/aws//modules/iam-assumable-roles"

  create_admin_role = true
  admin_role_name   = "${each.key}-admin"

  create_poweruser_role = true
  poweruser_role_name   = "${each.key}-poweruser"

  create_readonly_role       = true
  readonly_role_name         = "${each.key}-readonly"
  readonly_role_requires_mfa = false
}

module "machines" {
  source = "terraform-aws-modules/iam/aws//modules/iam-assumable-roles"

  for_each = { for name in var.machine_names : name => {} }

  trusted_role_arns = [module.repository.readonly_iam_role_arn]

  create_admin_role = true
  admin_role_name   = "${each.key}-admin"

  create_poweruser_role = true
  poweruser_role_name   = "${each.key}-poweruser"

  create_readonly_role       = true
  readonly_role_name         = "${each.key}-readonly"
  readonly_role_requires_mfa = false
}

module "devs" {
  source = "terraform-aws-modules/iam/aws//modules/iam-assumable-roles"

  for_each = { for name in var.dev_names : name => {} }

  trusted_role_arns = concat([module.repository.readonly_iam_role_arn], module.machines[*].readonly_iam_role_arn)

  create_admin_role = true
  admin_role_name   = "${each.key}-admin"

  create_poweruser_role = true
  poweruser_role_name   = "${each.key}-poweruser"

  create_readonly_role = false
  readonly_role_name   = "${each.key}-readonly"
}

module "admins" {
  source = "terraform-aws-modules/iam/aws//modules/iam-assumable-roles"

  for_each = { for name in var.admin_names : name => {} }

  trusted_role_arns = concat([module.repository.admin_iam_role_arn], module.machines[*].admin_iam_role_arn, module.devs[*].admin_iam_role_arn)

  create_admin_role = true
  admin_role_name   = "${each.key}-admin"

  create_poweruser_role = true
  poweruser_role_name   = "${each.key}-poweruser"

  create_readonly_role = false
  readonly_role_name   = "${each.key}-readonly"
}
