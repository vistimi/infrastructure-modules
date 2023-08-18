generate "versions" {
  path      = "version_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.4.0"
}
EOF
}

generate "provider" {
  path      = "provider_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "github" {
  version = "~> 5.0"
  token = "${get_env("GITHUB_TOKEN")}"
}
EOF
}
