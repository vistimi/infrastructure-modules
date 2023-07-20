# https://registry.terraform.io/modules/terraform-aws-modules/iam/aws/latest

locals {
  type_name_to_user_names = {
    resource = [for resource in var.resources : resource.name]
    machine  = [for machine in var.machines : machine.name]
    admin    = [for admin in var.admins : admin.name]
    dev      = [for dev in var.devs : dev.name]
  }
}

#---------------
#     Users
#---------------
module "resource_users" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "5.28.0"

  for_each = { for name in local.type_name_to_user_names.resource : name => {} }

  name          = each.key
  force_destroy = false

  create_iam_access_key = true

  password_reset_required = false

  tags = {}
}

module "machine_users" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "5.28.0"

  for_each = { for name in local.type_name_to_user_names.machine : name => {} }

  name          = each.key
  force_destroy = true

  create_iam_access_key = true

  password_reset_required = false

  tags = {}
}

module "dev_users" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "5.28.0"

  for_each = { for name in local.type_name_to_user_names.dev : name => {} }

  name          = each.key
  force_destroy = true

  create_iam_access_key = true

  password_reset_required = false

  tags = {}
}

module "admin_users" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "5.28.0"

  for_each = { for name in local.type_name_to_user_names.admin : name => {} }

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
module "resource_mutable_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-roles"
  version = "5.28.0"

  trusted_role_arns = ["*"]

  create_admin_role = true
  admin_role_name   = "resource-mutable-admin"

  create_poweruser_role = true
  poweruser_role_name   = "resource-mutable-poweruser"

  create_readonly_role       = true
  readonly_role_requires_mfa = false
  readonly_role_name         = "resource-mutable-readonly"
}

module "resource_immutable_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-roles"
  version = "5.28.0"

  trusted_role_arns = ["*"]

  create_admin_role = true
  admin_role_name   = "resource-immutable-admin"

  create_poweruser_role = true
  poweruser_role_name   = "resource-immutable-poweruser"

  create_readonly_role       = true
  readonly_role_requires_mfa = false
  readonly_role_name         = "resource-immutable-readonly"
}

module "machine_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-roles"
  version = "5.28.0"

  trusted_role_arns = [module.resource_mutable_role.poweruser_iam_role_arn, module.resource_immutable_role.readonly_iam_role_arn]

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

  trusted_role_arns = [module.resource_mutable_role.poweruser_iam_role_arn, module.resource_immutable_role.readonly_iam_role_arn, module.machine_role.readonly_iam_role_arn]

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

  trusted_role_arns = [module.resource_mutable_role.admin_iam_role_arn, module.resource_immutable_role.admin_iam_role_arn, module.machine_role.admin_iam_role_arn, module.dev_role.admin_iam_role_arn]

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
module "resource_mutable_group" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-group-with-assumable-roles-policy"
  version = "5.28.0"

  name = "resource-mutable"

  assumable_roles = [module.resource_mutable_role.poweruser_iam_role_arn]

  group_users = [for resource in var.resources : resource.name if resource.mutable]

  tags = {}
}

module "resource_immutable_group" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-group-with-assumable-roles-policy"
  version = "5.28.0"

  name = "resource-immutable"

  assumable_roles = [module.resource_immutable_role.poweruser_iam_role_arn]

  group_users = [for resource in var.resources : resource.name if !resource.mutable]

  tags = {}
}

module "machine_group" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-group-with-assumable-roles-policy"
  version = "5.28.0"

  name = "machine"

  assumable_roles = [module.machine_role.poweruser_iam_role_arn]

  group_users = local.type_name_to_user_names.machine

  tags = {}
}


module "dev_group" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-group-with-assumable-roles-policy"
  version = "5.28.0"

  name = "dev"

  assumable_roles = [module.dev_role.poweruser_iam_role_arn]

  group_users = local.type_name_to_user_names.dev

  tags = {}
}


module "admin_group" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-group-with-assumable-roles-policy"
  version = "5.28.0"

  name = "admin"

  assumable_roles = [module.admin_role.admin_iam_role_arn]

  group_users = local.type_name_to_user_names.admin

  tags = {}
}
