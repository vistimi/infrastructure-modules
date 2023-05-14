include {
  path = find_in_parent_folders()
}

terraform {
  extra_arguments "vpc_var" {
    commands = get_terraform_commands_that_need_vars()

    arguments = [
      "-var-file=${get_terragrunt_dir()}/terraform_override.tfvars",
    ]
  }
}
