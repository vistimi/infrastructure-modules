output "repository" {
  value = {
    admin_iam_role_arn              = module.repository.admin_iam_role_arn
    admin_iam_role_name             = module.repository.admin_iam_role_name
    admin_iam_role_path             = module.repository.admin_iam_role_path
    admin_iam_role_unique_id        = module.repository.admin_iam_role_unique_id
    admin_iam_role_requires_mfa     = module.repository.admin_iam_role_requires_mfa
    poweruser_iam_role_arn          = module.repository.poweruser_iam_role_arn
    poweruser_iam_role_name         = module.repository.poweruser_iam_role_name
    poweruser_iam_role_path         = module.repository.poweruser_iam_role_path
    poweruser_iam_role_unique_id    = module.repository.poweruser_iam_role_unique_id
    poweruser_iam_role_requires_mfa = module.repository.poweruser_iam_role_requires_mfa
    readonly_iam_role_arn           = module.repository.readonly_iam_role_arn
    readonly_iam_role_name          = module.repository.readonly_iam_role_name
    readonly_iam_role_path          = module.repository.readonly_iam_role_path
    readonly_iam_role_unique_id     = module.repository.readonly_iam_role_unique_id
    readonly_iam_role_requires_mfa  = module.repository.readonly_iam_role_requires_mfa
  }
}

output "machines" {
  value = {
    for key, user in module.machines : key => {
      admin_iam_role_arn              = user.admin_iam_role_arn
      admin_iam_role_name             = user.admin_iam_role_name
      admin_iam_role_path             = user.admin_iam_role_path
      admin_iam_role_unique_id        = user.admin_iam_role_unique_id
      admin_iam_role_requires_mfa     = user.admin_iam_role_requires_mfa
      poweruser_iam_role_arn          = user.poweruser_iam_role_arn
      poweruser_iam_role_name         = user.poweruser_iam_role_name
      poweruser_iam_role_path         = user.poweruser_iam_role_path
      poweruser_iam_role_unique_id    = user.poweruser_iam_role_unique_id
      poweruser_iam_role_requires_mfa = user.poweruser_iam_role_requires_mfa
      readonly_iam_role_arn           = user.readonly_iam_role_arn
      readonly_iam_role_name          = user.readonly_iam_role_name
      readonly_iam_role_path          = user.readonly_iam_role_path
      readonly_iam_role_unique_id     = user.readonly_iam_role_unique_id
      readonly_iam_role_requires_mfa  = user.readonly_iam_role_requires_mfa
    }
  }
}

output "devs" {
  value = {
    for key, user in module.devs : key => {
      admin_iam_role_arn              = user.admin_iam_role_arn
      admin_iam_role_name             = user.admin_iam_role_name
      admin_iam_role_path             = user.admin_iam_role_path
      admin_iam_role_unique_id        = user.admin_iam_role_unique_id
      admin_iam_role_requires_mfa     = user.admin_iam_role_requires_mfa
      poweruser_iam_role_arn          = user.poweruser_iam_role_arn
      poweruser_iam_role_name         = user.poweruser_iam_role_name
      poweruser_iam_role_path         = user.poweruser_iam_role_path
      poweruser_iam_role_unique_id    = user.poweruser_iam_role_unique_id
      poweruser_iam_role_requires_mfa = user.poweruser_iam_role_requires_mfa
      readonly_iam_role_arn           = user.readonly_iam_role_arn
      readonly_iam_role_name          = user.readonly_iam_role_name
      readonly_iam_role_path          = user.readonly_iam_role_path
      readonly_iam_role_unique_id     = user.readonly_iam_role_unique_id
      readonly_iam_role_requires_mfa  = user.readonly_iam_role_requires_mfa
    }
  }
}

output "admins" {
  value = {
    for key, user in module.admins : key => {
      admin_iam_role_arn              = user.admin_iam_role_arn
      admin_iam_role_name             = user.admin_iam_role_name
      admin_iam_role_path             = user.admin_iam_role_path
      admin_iam_role_unique_id        = user.admin_iam_role_unique_id
      admin_iam_role_requires_mfa     = user.admin_iam_role_requires_mfa
      poweruser_iam_role_arn          = user.poweruser_iam_role_arn
      poweruser_iam_role_name         = user.poweruser_iam_role_name
      poweruser_iam_role_path         = user.poweruser_iam_role_path
      poweruser_iam_role_unique_id    = user.poweruser_iam_role_unique_id
      poweruser_iam_role_requires_mfa = user.poweruser_iam_role_requires_mfa
      readonly_iam_role_arn           = user.readonly_iam_role_arn
      readonly_iam_role_name          = user.readonly_iam_role_name
      readonly_iam_role_path          = user.readonly_iam_role_path
      readonly_iam_role_unique_id     = user.readonly_iam_role_unique_id
      readonly_iam_role_requires_mfa  = user.readonly_iam_role_requires_mfa
    }
  }
}
