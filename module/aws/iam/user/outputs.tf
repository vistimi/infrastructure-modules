output "user" {
  value = {
    iam_user_name                                 = module.user.iam_user_name
    iam_user_arn                                  = module.user.iam_user_arn
    iam_user_unique_id                            = module.user.iam_user_unique_id
    iam_user_login_profile_key_fingerprint        = module.user.iam_user_login_profile_key_fingerprint
    iam_user_login_profile_encrypted_password     = module.user.iam_user_login_profile_encrypted_password
    iam_access_key_id                             = module.user.iam_access_key_id
    iam_access_key_key_fingerprint                = module.user.iam_access_key_key_fingerprint
    iam_access_key_encrypted_secret               = module.user.iam_access_key_encrypted_secret
    iam_access_key_encrypted_ses_smtp_password_v4 = module.user.iam_access_key_encrypted_ses_smtp_password_v4
    iam_access_key_status                         = module.user.iam_access_key_status
    pgp_key                                       = module.user.pgp_key
    keybase_password_decrypt_command              = module.user.keybase_password_decrypt_command
    keybase_password_pgp_message                  = module.user.keybase_password_pgp_message
    keybase_secret_key_decrypt_command            = module.user.keybase_secret_key_decrypt_command
    keybase_secret_key_pgp_message                = module.user.keybase_secret_key_pgp_message
    keybase_ses_smtp_password_v4_decrypt_command  = module.user.keybase_ses_smtp_password_v4_decrypt_command
    keybase_ses_smtp_password_v4_pgp_message      = module.user.keybase_ses_smtp_password_v4_pgp_message
    iam_user_ssh_key_ssh_public_key_id            = module.user.iam_user_ssh_key_ssh_public_key_id
    iam_user_ssh_key_fingerprint                  = module.user.iam_user_ssh_key_fingerprint
    policy_arns                                   = module.user.policy_arns
  }
}

output "user_sensitive" {
  value = {
    iam_user_login_profile_password     = sensitive(module.user.iam_user_login_profile_password)
    iam_access_key_secret               = sensitive(module.user.iam_access_key_secret)
    iam_access_key_ses_smtp_password_v4 = sensitive(module.user.iam_access_key_ses_smtp_password_v4)
  }
  sensitive = true
}

output "secret_manager" {
  value = module.secret_manager
}

# output "account" {
#   value = {
#     caller_identity_account_id                   = module.accounts.caller_identity_account_id
#     caller_identity_arn                          = module.accounts.caller_identity_arn
#     caller_identity_user_id                      = module.accounts.caller_identity_user_id
#     iam_account_password_policy_expire_passwords = module.accounts.iam_account_password_policy_expire_passwords
#   }
# }
