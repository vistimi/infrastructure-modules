output "groups" {
  value = {
    for group_name, group in module.groups : group_name => {
      users = group.users
      role  = group.role
      group = group.group
    }
  }
}

output "groups_sensitive" {
  value = {
    for group_name, group in module.groups : group_name => {
      users = sensitive(group.users_sensitive)
    }
  }
  sensitive = true
}
