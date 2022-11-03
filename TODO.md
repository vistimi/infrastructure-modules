The env.hcl configuration will look like the following:

locals {
  env = "qa" # this will be prod in the prod folder, and stage in the stage folder.
}
We can then load the env.hcl file in the _env/app.hcl file to load the env string:

locals {
  # Load the relevant env.hcl file based on where terragrunt was invoked. This works because find_in_parent_folders
  # always works at the context of the child configuration.
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env_name = local.env_vars.locals.env


  --------------
you can use git diff to collect all the files that changed, and for those terragrunt.hcl files that were updated, you can run terragrunt plan or terragrunt apply by passing in the updated file with --terragrunt-config.

  However, for include blocks, you can use the –terragrunt-modules-that-include CLI option for the run-all command.


  --------------

terraform {
  # Force Terraform to keep trying to acquire a lock for up to 20 minutes if someone else already has the lock
  extra_arguments "retry_lock" {
    commands  = get_terraform_commands_that_need_locking()
    arguments = ["-lock-timeout=20m"]
  }

  # Pass custom var files to Terraform
  extra_arguments "custom_vars" {
    commands = [
      "apply",
      "plan",
      "import",
      "push",
      "refresh"
    ]

    arguments = [
      "-var", "foo=bar",
      "-var", "region=us-west-1"
    ]
  }
}


--------------------

Add a file with the credentials that is required for every person/machine
Git workflow running with devcontainer image and execute the workflow


-------------------

terragrunt run-all apply


---------------------

dependency "mysql" {
  config_path = "../mysql"
}

dependency "redis" {
  config_path = "../redis"
}

inputs = {
  mysql_url = dependency.mysql.outputs.domain
  redis_url = dependency.redis.outputs.domain
}