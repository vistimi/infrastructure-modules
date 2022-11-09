# Include all settings from the root terragrunt.hcl file
include {
  path = find_in_parent_folders()
}

terraform {
  extra_arguments "vpc_var" {
    commands = [
      "apply",
      "plan",
      "import",
      "push",
      "refresh"
    ]

    arguments = [
      "-var-file=${get_terragrunt_dir()}/terraform_override.tfvars",
    ]
  }
}