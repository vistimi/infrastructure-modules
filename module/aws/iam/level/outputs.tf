output "user" {
  value = {
    iam_user_name                                 = module.level_user.iam_user_name
    iam_user_arn                                  = module.level_user.iam_user_arn
    iam_user_unique_id                            = module.level_user.iam_user_unique_id
    iam_user_login_profile_key_fingerprint        = module.level_user.iam_user_login_profile_key_fingerprint
    iam_user_login_profile_encrypted_password     = module.level_user.iam_user_login_profile_encrypted_password
    iam_access_key_id                             = module.level_user.iam_access_key_id
    iam_access_key_key_fingerprint                = module.level_user.iam_access_key_key_fingerprint
    iam_access_key_encrypted_secret               = module.level_user.iam_access_key_encrypted_secret
    iam_access_key_encrypted_ses_smtp_password_v4 = module.level_user.iam_access_key_encrypted_ses_smtp_password_v4
    iam_access_key_status                         = module.level_user.iam_access_key_status
    pgp_key                                       = module.level_user.pgp_key
    keybase_password_decrypt_command              = module.level_user.keybase_password_decrypt_command
    keybase_password_pgp_message                  = module.level_user.keybase_password_pgp_message
    keybase_secret_key_decrypt_command            = module.level_user.keybase_secret_key_decrypt_command
    keybase_secret_key_pgp_message                = module.level_user.keybase_secret_key_pgp_message
    keybase_ses_smtp_password_v4_decrypt_command  = module.level_user.keybase_ses_smtp_password_v4_decrypt_command
    keybase_ses_smtp_password_v4_pgp_message      = module.level_user.keybase_ses_smtp_password_v4_pgp_message
    iam_user_ssh_key_ssh_public_key_id            = module.level_user.iam_user_ssh_key_ssh_public_key_id
    iam_user_ssh_key_fingerprint                  = module.level_user.iam_user_ssh_key_fingerprint
    policy_arns                                   = module.level_user.policy_arns
  }
}

output "user_sensitive" {
  value = {
    iam_user_login_profile_password     = sensitive(module.level_user.iam_user_login_profile_password)
    iam_access_key_secret               = sensitive(module.level_user.iam_access_key_secret)
    iam_access_key_ses_smtp_password_v4 = sensitive(module.level_user.iam_access_key_ses_smtp_password_v4)
  }
  sensitive = true
}

output "secret_manager" {
  value = module.secret_manager
}

output "role" {
  value = {
    admin_iam_role_arn              = module.level_role.admin_iam_role_arn
    admin_iam_role_name             = module.level_role.admin_iam_role_name
    admin_iam_role_path             = module.level_role.admin_iam_role_path
    admin_iam_role_unique_id        = module.level_role.admin_iam_role_unique_id
    admin_iam_role_requires_mfa     = module.level_role.admin_iam_role_requires_mfa
    poweruser_iam_role_arn          = module.level_role.poweruser_iam_role_arn
    poweruser_iam_role_name         = module.level_role.poweruser_iam_role_name
    poweruser_iam_role_path         = module.level_role.poweruser_iam_role_path
    poweruser_iam_role_unique_id    = module.level_role.poweruser_iam_role_unique_id
    poweruser_iam_role_requires_mfa = module.level_role.poweruser_iam_role_requires_mfa
    readonly_iam_role_arn           = module.level_role.readonly_iam_role_arn
    readonly_iam_role_name          = module.level_role.readonly_iam_role_name
    readonly_iam_role_path          = module.level_role.readonly_iam_role_path
    readonly_iam_role_unique_id     = module.level_role.readonly_iam_role_unique_id
    readonly_iam_role_requires_mfa  = module.level_role.readonly_iam_role_requires_mfa
  }
}

output "group" {
  value = {
    group_users     = module.level_group.group_users
    assumable_roles = module.level_group.assumable_roles
    policy_arn      = module.level_group.policy_arn
    group_name      = module.level_group.group_name
    group_arn       = module.level_group.group_arn
  }
}
