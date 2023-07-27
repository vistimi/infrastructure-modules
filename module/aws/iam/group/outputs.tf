# output "users" {
#   value = {
#     for user_name, user in module.users : user_name => {
#       iam_user_name                                 = user.iam_user_name
#       iam_user_arn                                  = user.iam_user_arn
#       iam_user_unique_id                            = user.iam_user_unique_id
#       iam_user_login_profile_key_fingerprint        = user.iam_user_login_profile_key_fingerprint
#       iam_user_login_profile_encrypted_password     = user.iam_user_login_profile_encrypted_password
#       iam_access_key_id                             = user.iam_access_key_id
#       iam_access_key_key_fingerprint                = user.iam_access_key_key_fingerprint
#       iam_access_key_encrypted_secret               = user.iam_access_key_encrypted_secret
#       iam_access_key_encrypted_ses_smtp_password_v4 = user.iam_access_key_encrypted_ses_smtp_password_v4
#       iam_access_key_status                         = user.iam_access_key_status
#       pgp_key                                       = user.pgp_key
#       keybase_password_decrypt_command              = user.keybase_password_decrypt_command
#       keybase_password_pgp_message                  = user.keybase_password_pgp_message
#       keybase_secret_key_decrypt_command            = user.keybase_secret_key_decrypt_command
#       keybase_secret_key_pgp_message                = user.keybase_secret_key_pgp_message
#       keybase_ses_smtp_password_v4_decrypt_command  = user.keybase_ses_smtp_password_v4_decrypt_command
#       keybase_ses_smtp_password_v4_pgp_message      = user.keybase_ses_smtp_password_v4_pgp_message
#       iam_user_ssh_key_ssh_public_key_id            = user.iam_user_ssh_key_ssh_public_key_id
#       iam_user_ssh_key_fingerprint                  = user.iam_user_ssh_key_fingerprint
#       policy_arns                                   = user.policy_arns
#     }
#   }
# }

# output "users_sensitive" {
#   value = {
#     for user_name, user in module.users : user_name => {
#       iam_user_login_profile_password     = sensitive(user.iam_user_login_profile_password)
#       iam_access_key_secret               = sensitive(user.iam_access_key_secret)
#       iam_access_key_ses_smtp_password_v4 = sensitive(user.iam_access_key_ses_smtp_password_v4)
#     }
#   }
#   sensitive = true
# }

# output "secret_manager" {
#   value = module.secret_manager
# }

# output "accounts" {
#   value = {
#     for user_name, account in module.accounts : user_name => {
#       caller_identity_account_id                   = account.caller_identity_account_id
#       caller_identity_arn                          = account.caller_identity_arn
#       caller_identity_user_id                      = account.caller_identity_user_id
#       iam_account_password_policy_expire_passwords = account.iam_account_password_policy_expire_passwords
#     }
#   }
# }

output "users" {
  value = {
    for user_name, user in module.users : user_name => {
      user           = user.user
      secret_manager = user.secret_manager
    }
  }
}

# output "users_sensitive" {
#   value = {
#     for user_name, user in module.users : user_name => {
#       user_sensitive = sensitive(user.user_sensitive)
#     }
#   }
#   sensitive = true
# }

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
