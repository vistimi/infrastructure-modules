# VPC
Create a file called `terraform.tfvars` in the same folder to load the variables inside the configuration.
They must match the variables defined inside `variables.tf`.

```hcl
region           = "us-east-1"
project_name     = "test"
environment_name = "trunk"
common_tags      = { region = "us-east-1", ... }
vpc_cidr_ipv4    = "160.0.0.0/16"
backup_name = "terraform-state-baackup"
```