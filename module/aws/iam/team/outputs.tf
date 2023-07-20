output "users" {
  value = {
    for type_name, users in {
      "resource" = module.resource_users,
      "machine"  = module.machine_users,
      "admin"    = module.admin_users,
      "dev"      = module.dev_users,
      } : type_name => {
      for user_name in local.type_name_to_user_names[type_name] : user_name => {
        iam_user_name                                 = users[user_name].iam_user_name
        iam_user_arn                                  = users[user_name].iam_user_arn
        iam_user_unique_id                            = users[user_name].iam_user_unique_id
        iam_user_login_profile_key_fingerprint        = users[user_name].iam_user_login_profile_key_fingerprint
        iam_user_login_profile_encrypted_password     = users[user_name].iam_user_login_profile_encrypted_password
        iam_user_login_profile_password               = users[user_name].iam_user_login_profile_password
        iam_access_key_id                             = users[user_name].iam_access_key_id
        iam_access_key_secret                         = users[user_name].iam_access_key_secret
        iam_access_key_key_fingerprint                = users[user_name].iam_access_key_key_fingerprint
        iam_access_key_encrypted_secret               = users[user_name].iam_access_key_encrypted_secret
        iam_access_key_ses_smtp_password_v4           = users[user_name].iam_access_key_ses_smtp_password_v4
        iam_access_key_encrypted_ses_smtp_password_v4 = users[user_name].iam_access_key_encrypted_ses_smtp_password_v4
        iam_access_key_status                         = users[user_name].iam_access_key_status
        pgp_key                                       = users[user_name].pgp_key
        keybase_password_decrypt_command              = users[user_name].keybase_password_decrypt_command
        keybase_password_pgp_message                  = users[user_name].keybase_password_pgp_message
        keybase_secret_key_decrypt_command            = users[user_name].keybase_secret_key_decrypt_command
        keybase_secret_key_pgp_message                = users[user_name].keybase_secret_key_pgp_message
        keybase_ses_smtp_password_v4_decrypt_command  = users[user_name].keybase_ses_smtp_password_v4_decrypt_command
        keybase_ses_smtp_password_v4_pgp_message      = users[user_name].keybase_ses_smtp_password_v4_pgp_message
        iam_user_ssh_key_ssh_public_key_id            = users[user_name].iam_user_ssh_key_ssh_public_key_id
        iam_user_ssh_key_fingerprint                  = users[user_name].iam_user_ssh_key_fingerprint
        policy_arns                                   = users[user_name].policy_arns
      }
    }
  }
  sensitive = true
}

# output "accounts" {
#   value = {
#     for type_name, accounts in {
#       "resource" = module.resource_accounts,
#       "machine"  = module.machine_accounts,
#       "admin"    = module.admin_accounts,
#       "dev"      = module.dev_accounts,
#       } : type_name => {
#       for user_name in local.type_name_to_user_names[type_name] : user_name => {
#         caller_identity_account_id                   = accounts[user_name].caller_identity_account_id
#         caller_identity_arn                          = accounts[user_name].caller_identity_arn
#         caller_identity_user_id                      = accounts[user_name].caller_identity_user_id
#         iam_account_password_policy_expire_passwords = accounts[user_name].iam_account_password_policy_expire_passwords
#       }
#     }
#   }
#   sensitive = true
# }

output "roles" {
  value = {
    for type_name, role in {
      "resource-mutable"   = module.resource_mutable_role,
      "resource-immutable" = module.resource_immutable_role,
      "machine"            = module.machine_role,
      "admin"              = module.admin_role,
      "dev"                = module.dev_role,
      } : type_name => {
      admin_iam_role_arn              = role.admin_iam_role_arn
      admin_iam_role_name             = role.admin_iam_role_name
      admin_iam_role_path             = role.admin_iam_role_path
      admin_iam_role_unique_id        = role.admin_iam_role_unique_id
      admin_iam_role_requires_mfa     = role.admin_iam_role_requires_mfa
      poweruser_iam_role_arn          = role.poweruser_iam_role_arn
      poweruser_iam_role_name         = role.poweruser_iam_role_name
      poweruser_iam_role_path         = role.poweruser_iam_role_path
      poweruser_iam_role_unique_id    = role.poweruser_iam_role_unique_id
      poweruser_iam_role_requires_mfa = role.poweruser_iam_role_requires_mfa
      readonly_iam_role_arn           = role.readonly_iam_role_arn
      readonly_iam_role_name          = role.readonly_iam_role_name
      readonly_iam_role_path          = role.readonly_iam_role_path
      readonly_iam_role_unique_id     = role.readonly_iam_role_unique_id
      readonly_iam_role_requires_mfa  = role.readonly_iam_role_requires_mfa
    }
  }
}

output "groups" {
  value = {
    for type_name, group in {
      "resource-mutable"   = module.resource_mutable_group,
      "resource-immutable" = module.resource_immutable_group,
      "machine"            = module.machine_group,
      "admin"              = module.admin_group,
      "dev"                = module.dev_group,
      } : type_name => {
      group_users     = group.group_users
      assumable_roles = group.assumable_roles
      policy_arn      = group.policy_arn
      group_name      = group.group_name
      group_arn       = group.group_arn
    }
  }
}
