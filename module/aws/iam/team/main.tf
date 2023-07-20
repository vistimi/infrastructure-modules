# https://registry.terraform.io/modules/terraform-aws-modules/iam/aws/latest

locals {
  type_name_to_user_names = {
    "resource" = var.resource_names,
    "machine"  = var.machine_names,
    "admin"    = var.admin_names,
    "dev"      = var.dev_names,
  }
}

#---------------
#     Users
#---------------
module "resource_users" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "5.28.0"

  for_each = { for name in var.resource_names : name => {} }

  name          = each.key
  force_destroy = false

  create_iam_access_key = true

  password_reset_required = false

  tags = {}
}

module "machine_users" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "5.28.0"

  for_each = { for name in var.machine_names : name => {} }

  name          = each.key
  force_destroy = true

  create_iam_access_key = true

  password_reset_required = false

  tags = {}
}

module "dev_users" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "5.28.0"

  for_each = { for name in var.dev_names : name => {} }

  name          = each.key
  force_destroy = true

  create_iam_access_key = true

  password_reset_required = false

  tags = {}
}

module "admin_users" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "5.28.0"

  for_each = { for name in var.admin_names : name => {} }

  name          = each.key
  force_destroy = true

  create_iam_access_key = true

  password_reset_required = false

  tags = {}
}

#------------------
#     Accounts
#------------------
# module "resource_accounts" {
#   source = "terraform-aws-modules/iam/aws//modules/iam-account"
# version = "5.28.0"

#   for_each = { for name in var.resource_names : name => {} }

#   account_alias = module.resource_users[each.key].iam_user_name

#   minimum_password_length      = 20
#   require_lowercase_characters = true
#   require_uppercase_characters = true
#   require_numbers              = true
#   require_symbols              = true
# }

# module "machine_accounts" {
#   source = "terraform-aws-modules/iam/aws//modules/iam-account"
# version = "5.28.0"

#   for_each = { for name in var.machine_names : name => {} }

#   account_alias = module.machine_users[each.key].iam_user_unique_id

#   minimum_password_length      = 20
#   require_lowercase_characters = true
#   require_uppercase_characters = true
#   require_numbers              = true
#   require_symbols              = true
# }

# module "dev_accounts" {
#   source = "terraform-aws-modules/iam/aws//modules/iam-account"
# version = "5.28.0"

#   for_each = { for name in var.dev_names : name => {} }

#   account_alias = module.dev_users[each.key].iam_user_unique_id

#   minimum_password_length      = 20
#   require_lowercase_characters = true
#   require_uppercase_characters = true
#   require_numbers              = true
#   require_symbols              = true
# }

# module "admin_accounts" {
#   source = "terraform-aws-modules/iam/aws//modules/iam-account"
# version = "5.28.0"

#   for_each = { for name in var.admin_names : name => {} }

#   account_alias = module.admin_users[each.key].iam_user_unique_id

#   minimum_password_length      = 20
#   require_lowercase_characters = true
#   require_uppercase_characters = true
#   require_numbers              = true
#   require_symbols              = true
# }

#---------------
#     Roles
#---------------
module "resource_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-roles"
  version = "5.28.0"

  trusted_role_arns = ["*"]

  create_admin_role = true
  admin_role_name   = "resource-admin"

  create_poweruser_role = true
  poweruser_role_name   = "resource-poweruser"

  create_readonly_role       = true
  readonly_role_requires_mfa = false
  readonly_role_name         = "resource-readonly"
}

module "machine_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-roles"
  version = "5.28.0"

  trusted_role_arns = [module.resource_role.readonly_iam_role_arn]

  create_admin_role = true
  admin_role_name   = "machine-admin"

  create_poweruser_role = true
  poweruser_role_name   = "machine-poweruser"

  create_readonly_role       = true
  readonly_role_requires_mfa = false
  readonly_role_name         = "machine-readonly"
}

module "dev_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-roles"
  version = "5.28.0"

  trusted_role_arns = [module.resource_role.readonly_iam_role_arn, module.machine_role.readonly_iam_role_arn]

  create_admin_role = true
  admin_role_name   = "dev-admin"

  create_poweruser_role = true
  poweruser_role_name   = "dev-poweruser"

  create_readonly_role = false
  readonly_role_name   = "dev-readonly"
}

module "admin_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-roles"
  version = "5.28.0"

  trusted_role_arns = [module.resource_role.admin_iam_role_arn, module.machine_role.admin_iam_role_arn, module.dev_role.admin_iam_role_arn]

  create_admin_role = true
  admin_role_name   = "admin-admin"

  create_poweruser_role = true
  poweruser_role_name   = "admin-poweruser"

  create_readonly_role = false
  readonly_role_name   = "admin-readonly"
}

#---------------
#     Groups
#---------------
# set group roles
module "resource_group" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-group-with-assumable-roles-policy"
  version = "5.28.0"

  name = "resource"

  assumable_roles = [module.resource_role.poweruser_iam_role_arn]

  group_users = [for user in module.resource_users : user.iam_user_name]

  tags = {}
}

module "machine_group" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-group-with-assumable-roles-policy"
  version = "5.28.0"

  name = "machine"

  assumable_roles = [module.machine_role.poweruser_iam_role_arn]

  group_users = [for user in module.machine_users : user.iam_user_name]

  tags = {}
}


module "dev_group" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-group-with-assumable-roles-policy"
  version = "5.28.0"

  name = "dev"

  assumable_roles = [module.dev_role.poweruser_iam_role_arn]

  group_users = [for user in module.dev_users : user.iam_user_name]

  tags = {}
}


module "admin_group" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-group-with-assumable-roles-policy"
  version = "5.28.0"

  name = "admin"

  assumable_roles = [module.admin_role.admin_iam_role_arn]

  group_users = [for user in module.admin_users : user.iam_user_name]

  tags = {}
}
