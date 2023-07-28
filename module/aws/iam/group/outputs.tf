output "users" {
  value = {
    for user_name, user in module.users : user_name => {
      user           = user.user
      secret_manager = user.secret_manager
    }
  }
}

output "users_sensitive" {
  value = {
    for user_name, user in module.users : user_name => {
      user = sensitive(user.user_sensitive)
    }
  }
  sensitive = true
}

output "role" {
  value = {
    admin_iam_role_arn              = module.group_role.admin_iam_role_arn
    admin_iam_role_name             = module.group_role.admin_iam_role_name
    admin_iam_role_path             = module.group_role.admin_iam_role_path
    admin_iam_role_unique_id        = module.group_role.admin_iam_role_unique_id
    admin_iam_role_requires_mfa     = module.group_role.admin_iam_role_requires_mfa
    poweruser_iam_role_arn          = module.group_role.poweruser_iam_role_arn
    poweruser_iam_role_name         = module.group_role.poweruser_iam_role_name
    poweruser_iam_role_path         = module.group_role.poweruser_iam_role_path
    poweruser_iam_role_unique_id    = module.group_role.poweruser_iam_role_unique_id
    poweruser_iam_role_requires_mfa = module.group_role.poweruser_iam_role_requires_mfa
    readonly_iam_role_arn           = module.group_role.readonly_iam_role_arn
    readonly_iam_role_name          = module.group_role.readonly_iam_role_name
    readonly_iam_role_path          = module.group_role.readonly_iam_role_path
    readonly_iam_role_unique_id     = module.group_role.readonly_iam_role_unique_id
    readonly_iam_role_requires_mfa  = module.group_role.readonly_iam_role_requires_mfa
  }
}

output "group" {
  value = {
    group_users     = module.group.group_users
    assumable_roles = module.group.assumable_roles
    policy_arn      = module.group.policy_arn
    group_name      = module.group.group_name
    group_arn       = module.group.group_arn
  }
}
