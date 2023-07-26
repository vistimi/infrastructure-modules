output "groups" {
  value = {
    for group_key, group in merge(module.admin, module.dev, module.machine, module.resource_mutable, module.resource_immutable) : group_key => {
      users           = group.users
      users_sensitive = sensitive(group.users_sensitive)
      secret_manager  = group.secret_manager
      accounts        = group.accounts
      role            = group.role
      group           = group.group
    }
  }
}
