output "users" {
  value = {
    iam_user_name                                 = module.organization_user.iam_user_name
    iam_user_arn                                  = module.organization_user.iam_user_arn
    iam_user_unique_id                            = module.organization_user.iam_user_unique_id
    iam_user_login_profile_key_fingerprint        = module.organization_user.iam_user_login_profile_key_fingerprint
    iam_user_login_profile_encrypted_password     = module.organization_user.iam_user_login_profile_encrypted_password
    iam_access_key_id                             = module.organization_user.iam_access_key_id
    iam_access_key_key_fingerprint                = module.organization_user.iam_access_key_key_fingerprint
    iam_access_key_encrypted_secret               = module.organization_user.iam_access_key_encrypted_secret
    iam_access_key_encrypted_ses_smtp_password_v4 = module.organization_user.iam_access_key_encrypted_ses_smtp_password_v4
    iam_access_key_status                         = module.organization_user.iam_access_key_status
    pgp_key                                       = module.organization_user.pgp_key
    keybase_password_decrypt_command              = module.organization_user.keybase_password_decrypt_command
    keybase_password_pgp_message                  = module.organization_user.keybase_password_pgp_message
    keybase_secret_key_decrypt_command            = module.organization_user.keybase_secret_key_decrypt_command
    keybase_secret_key_pgp_message                = module.organization_user.keybase_secret_key_pgp_message
    keybase_ses_smtp_password_v4_decrypt_command  = module.organization_user.keybase_ses_smtp_password_v4_decrypt_command
    keybase_ses_smtp_password_v4_pgp_message      = module.organization_user.keybase_ses_smtp_password_v4_pgp_message
    iam_user_ssh_key_ssh_public_key_id            = module.organization_user.iam_user_ssh_key_ssh_public_key_id
    iam_user_ssh_key_fingerprint                  = module.organization_user.iam_user_ssh_key_fingerprint
    policy_arns                                   = module.organization_user.policy_arns
  }
}

output "users_sensitive" {
  value = {
    iam_user_login_profile_password     = sensitive(module.organization_user.iam_user_login_profile_password)
    iam_access_key_secret               = sensitive(module.organization_user.iam_access_key_secret)
    iam_access_key_ses_smtp_password_v4 = sensitive(module.organization_user.iam_access_key_ses_smtp_password_v4)
  }
  sensitive = true
}

output "secret_manager" {
  value = module.secret_manager
}

output "roles" {
  value = {
    admin_iam_role_arn              = module.organization_role.admin_iam_role_arn
    admin_iam_role_name             = module.organization_role.admin_iam_role_name
    admin_iam_role_path             = module.organization_role.admin_iam_role_path
    admin_iam_role_unique_id        = module.organization_role.admin_iam_role_unique_id
    admin_iam_role_requires_mfa     = module.organization_role.admin_iam_role_requires_mfa
    poweruser_iam_role_arn          = module.organization_role.poweruser_iam_role_arn
    poweruser_iam_role_name         = module.organization_role.poweruser_iam_role_name
    poweruser_iam_role_path         = module.organization_role.poweruser_iam_role_path
    poweruser_iam_role_unique_id    = module.organization_role.poweruser_iam_role_unique_id
    poweruser_iam_role_requires_mfa = module.organization_role.poweruser_iam_role_requires_mfa
    readonly_iam_role_arn           = module.organization_role.readonly_iam_role_arn
    readonly_iam_role_name          = module.organization_role.readonly_iam_role_name
    readonly_iam_role_path          = module.organization_role.readonly_iam_role_path
    readonly_iam_role_unique_id     = module.organization_role.readonly_iam_role_unique_id
    readonly_iam_role_requires_mfa  = module.organization_role.readonly_iam_role_requires_mfa
  }
}

output "groups" {
  value = {
    group_users     = module.organization_group.group_users
    assumable_roles = module.organization_group.assumable_roles
    policy_arn      = module.organization_group.policy_arn
    group_name      = module.organization_group.group_name
    group_arn       = module.organization_group.group_arn
  }
}
