# https://registry.terraform.io/modules/terraform-aws-modules/iam/aws/latest

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  region_name        = data.aws_region.current.name
  tags               = merge(var.tags, { Team = var.name, RootAccountId = data.aws_caller_identity.current.account_id, RootAccountArn = data.aws_caller_identity.current.arn, Region = local.region_name })
  pw_length_resource = 20
  pw_length_machine  = 20
  pw_length_dev      = 20
  pw_length_admin    = 20
}

#---------------
#     Users
#---------------
module "resource_mutable_users" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "5.28.0"

  for_each = { for resource in var.resources : resource.name => { mutable = resource.mutable } if resource.mutable }

  name          = "${var.name}-${each.key}"
  force_destroy = false

  create_iam_access_key = true

  password_length         = local.pw_length_resource
  password_reset_required = false

  tags = merge(local.tags, { Account = "${var.name}-${each.key}", Role = "resource-mutable" })
}

module "resource_immutable_users" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "5.28.0"

  for_each = { for resource in var.resources : resource.name => { mutable = resource.mutable } if !resource.mutable }

  name          = "${var.name}-${each.key}"
  force_destroy = false

  create_iam_access_key = true

  password_length         = local.pw_length_resource
  password_reset_required = false

  tags = merge(local.tags, { Account = "${var.name}-${each.key}", Role = "resource-immutable" })
}

module "machine_users" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "5.28.0"

  for_each = { for machine in var.machines : machine.name => {} }

  name          = "${var.name}-${each.key}"
  force_destroy = true

  create_iam_access_key = true

  password_length         = local.pw_length_machine
  password_reset_required = false

  tags = merge(local.tags, { Account = "${var.name}-${each.key}", Role = "machine" })
}

module "dev_users" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "5.28.0"

  for_each = { for dev in var.devs : dev.name => {} }

  name          = "${var.name}-${each.key}"
  force_destroy = true

  create_iam_access_key = true

  password_length         = local.pw_length_dev
  password_reset_required = false

  tags = merge(local.tags, { Account = "${var.name}-${each.key}", Role = "dev" })
}

module "admin_users" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "5.28.0"

  for_each = { for admin in var.admins : admin.name => {} }

  name          = "${var.name}-${each.key}"
  force_destroy = true

  create_iam_access_key = true

  password_length         = local.pw_length_admin
  password_reset_required = false

  tags = merge(local.tags, { Account = "${var.name}-${each.key}", Role = "admin" })
}

#---------------
#     Secrets
#---------------
module "secret_manager" {
  source = "../../secret/manager"

  for_each = { for name, user in merge(module.resource_mutable_users, module.resource_immutable_users, module.machine_users, module.dev_users, module.admin_users) : name => user if var.store_secrets }

  names = ["team/${var.name}/user/${each.value.iam_user_name}"]
  secrets = [
    { key = "AWS_SECRET_KEY", value = sensitive(each.value.iam_access_key_secret) },
    { key = "AWS_ACCESS_KEY", value = each.value.iam_access_key_id },
    { key = "AWS_ACCOUNT_ID", value = each.value.iam_user_unique_id },
    { key = "AWS_PROFILE_NAME", value = each.value.iam_user_name },
    { key = "AWS_REGION_NAME", value = local.region_name },
    { key = "Password", value = each.value.iam_user_login_profile_password },
  ]

  tags = merge(local.tags, { Account = each.value.iam_user_name, Role = "" })
}

#------------------
#     Accounts
#------------------
module "resource_mutable_accounts" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-account"
  version = "5.28.0"

  for_each = { for resource in var.resources : resource.name => { mutable = resource.mutable } if resource.mutable }

  account_alias = lower(module.resource_mutable_users[each.key].iam_user_name)

  minimum_password_length      = local.pw_length_resource
  require_lowercase_characters = true
  require_uppercase_characters = true
  require_numbers              = true
  require_symbols              = true
}

module "resource_immutable_accounts" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-account"
  version = "5.28.0"

  for_each = { for resource in var.resources : resource.name => { mutable = resource.mutable } if !resource.mutable }

  account_alias = lower(module.resource_immutable_users[each.key].iam_user_name)

  minimum_password_length      = local.pw_length_resource
  require_lowercase_characters = true
  require_uppercase_characters = true
  require_numbers              = true
  require_symbols              = true
}

module "machine_accounts" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-account"
  version = "5.28.0"

  for_each = { for machine in var.machines : machine.name => {} }

  account_alias = lower(module.machine_users[each.key].iam_user_name)

  minimum_password_length      = local.pw_length_machine
  require_lowercase_characters = true
  require_uppercase_characters = true
  require_numbers              = true
  require_symbols              = true
}

module "dev_accounts" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-account"
  version = "5.28.0"

  for_each = { for dev in var.devs : dev.name => {} }

  account_alias = lower(module.dev_users[each.key].iam_user_name)

  minimum_password_length      = local.pw_length_dev
  require_lowercase_characters = true
  require_uppercase_characters = true
  require_numbers              = true
  require_symbols              = true
}

module "admin_accounts" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-account"
  version = "5.28.0"

  for_each = { for admin in var.admins : admin.name => {} }

  account_alias = lower(module.admin_users[each.key].iam_user_unique_id)

  minimum_password_length      = local.pw_length_admin
  require_lowercase_characters = true
  require_uppercase_characters = true
  require_numbers              = true
  require_symbols              = true
}

#---------------
#     Roles
#---------------
module "resource_mutable_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-roles"
  version = "5.28.0"

  for_each = length([for resource in var.resources : resource.name if resource.mutable]) > 0 ? { "${var.name}" = {} } : {}

  trusted_role_arns = ["*"]

  create_admin_role = true
  admin_role_name   = "${var.name}-resource-mutable-admin"

  create_poweruser_role = true
  poweruser_role_name   = "${var.name}-resource-mutable-poweruser"

  create_readonly_role       = true
  readonly_role_requires_mfa = false
  readonly_role_name         = "${var.name}-resource-mutable-readonly"
}

module "resource_immutable_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-roles"
  version = "5.28.0"

  for_each = length([for resource in var.resources : resource.name if !resource.mutable]) > 0 ? { "${var.name}" = {} } : {}

  trusted_role_arns = ["*"]

  create_admin_role = true
  admin_role_name   = "${var.name}-resource-immutable-admin"

  create_poweruser_role = true
  poweruser_role_name   = "${var.name}-resource-immutable-poweruser"

  create_readonly_role       = true
  readonly_role_requires_mfa = false
  readonly_role_name         = "${var.name}-resource-immutable-readonly"
}

module "machine_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-roles"
  version = "5.28.0"

  for_each = length([for machine in var.machines : machine.name]) > 0 ? { "${var.name}" = {} } : {}

  trusted_role_arns = concat(try([module.resource_mutable_role[each.key].poweruser_iam_role_arn], []), try([module.resource_immutable_role[each.key].readonly_iam_role_arn], []))

  create_admin_role = true
  admin_role_name   = "${var.name}-machine-admin"

  create_poweruser_role = true
  poweruser_role_name   = "${var.name}-machine-poweruser"

  create_readonly_role       = true
  readonly_role_requires_mfa = false
  readonly_role_name         = "${var.name}-machine-readonly"
}

module "dev_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-roles"
  version = "5.28.0"

  for_each = length([for dev in var.devs : dev.name]) > 0 ? { "${var.name}" = {} } : {}

  trusted_role_arns = concat(try([module.resource_mutable_role[each.key].poweruser_iam_role_arn], []), try([module.resource_immutable_role[each.key].readonly_iam_role_arn], []), try([module.machine_role[each.key].readonly_iam_role_arn], []))

  create_admin_role = true
  admin_role_name   = "${var.name}-dev-admin"

  create_poweruser_role = true
  poweruser_role_name   = "${var.name}-dev-poweruser"

  create_readonly_role = false
  readonly_role_name   = "${var.name}-dev-readonly"
}

module "admin_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-roles"
  version = "5.28.0"

  for_each = length([for admin in var.admins : admin.name]) > 0 ? { "${var.name}" = {} } : {}

  trusted_role_arns = concat(try([module.resource_mutable_role[each.key].admin_iam_role_arn], []), try([module.resource_immutable_role[each.key].admin_iam_role_arn], []), try([module.machine_role[each.key].admin_iam_role_arn], []), try([module.dev_role[each.key].admin_iam_role_arn], []))

  create_admin_role = true
  admin_role_name   = "${var.name}-admin-admin"

  create_poweruser_role = true
  poweruser_role_name   = "${var.name}-admin-poweruser"

  create_readonly_role = false
  readonly_role_name   = "${var.name}-admin-readonly"
}

#---------------
#     Groups
#---------------
# set group roles
module "resource_mutable_group" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-group-with-assumable-roles-policy"
  version = "5.28.0"

  for_each = length([for resource in var.resources : resource.name if resource.mutable]) > 0 ? { "${var.name}" = {} } : {}

  name = "${var.name}-resource-mutable"

  assumable_roles = concat(try([module.resource_mutable_role[each.key].poweruser_iam_role_arn], []), var.external_assume_role_arns)

  group_users = [for user in module.resource_mutable_users : user.iam_user_name]

  tags = merge(local.tags, { Role = "resource-mutable" })
}

module "resource_immutable_group" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-group-with-assumable-roles-policy"
  version = "5.28.0"

  for_each = length([for resource in var.resources : resource.name if !resource.mutable]) > 0 ? { "${var.name}" = {} } : {}

  name = "${var.name}-resource-immutable"

  assumable_roles = concat(try([module.resource_immutable_role[each.key].poweruser_iam_role_arn], []), var.external_assume_role_arns)

  group_users = [for user in module.resource_immutable_users : user.iam_user_name]

  tags = merge(local.tags, { Role = "resource-immutable" })
}

module "machine_group" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-group-with-assumable-roles-policy"
  version = "5.28.0"

  for_each = length([for machine in var.machines : machine.name]) > 0 ? { "${var.name}" = {} } : {}

  name = "${var.name}-machine"

  assumable_roles = concat(try([module.machine_role[each.key].poweruser_iam_role_arn], []), var.external_assume_role_arns)

  group_users = [for user in module.machine_users : user.iam_user_name]

  tags = merge(local.tags, { Role = "machine" })
}


module "dev_group" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-group-with-assumable-roles-policy"
  version = "5.28.0"

  for_each = length([for dev in var.devs : dev.name]) > 0 ? { "${var.name}" = {} } : {}

  name = "${var.name}-dev"

  assumable_roles = concat(try([module.dev_role[each.key].poweruser_iam_role_arn], []), var.external_assume_role_arns)

  group_users = [for user in module.dev_users : user.iam_user_name]

  tags = merge(local.tags, { Role = "dev" })
}


module "admin_group" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-group-with-assumable-roles-policy"
  version = "5.28.0"

  for_each = length([for admin in var.admins : admin.name]) > 0 ? { "${var.name}" = {} } : {}

  name = "${var.name}-admin"

  assumable_roles = concat(try([module.admin_role[each.key].admin_iam_role_arn], []), var.external_assume_role_arns)

  group_users = [for user in module.admin_users : user.iam_user_name]

  tags = merge(local.tags, { Role = "admin" })
}
