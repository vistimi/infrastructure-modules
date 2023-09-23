include {
  path = find_in_parent_folders()
}

locals {
  microservice       = read_terragrunt_config("${get_terragrunt_dir()}/microservice_override.hcl")
  aws_account_vars   = read_terragrunt_config(find_in_parent_folders("aws_account_override.hcl"))
  aws_account_id     = local.aws_account_vars.locals.aws_account_id
  aws_account_region = local.aws_account_vars.locals.aws_account_region
}

# Generate version block
generate "versions" {
  path      = "version_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.1"
    }
    # kubectl = {
    #   source  = "gavinbunney/kubectl"
    #   version = "= 1.14.0"
    # }
    # helm = {
    #   source  = "hashicorp/helm"
    #   version = "2.5.0"
    # }
    # kubernetes = {
    #   source  = "hashicorp/kubernetes"
    #   version = "2.0.1"
    # }
  }
  required_version = ">= 1.4.0"
}
EOF
}

# generate "provider" {
#   path      = "provider_override.tf"
#   if_exists = "overwrite_terragrunt"
#   contents  = <<EOF
# provider "aws" {
#   region = "${local.aws_account_region}"
#   allowed_account_ids = ["${local.aws_account_id}"]
# }
# EOF
# }

generate "provider" {
  path      = "provider_kubernetes_override.tf"
  if_exists = "overwrite_terragrunt"
  contents = <<EOF
provider "aws" {
  region = "${local.aws_account_region}"
  allowed_account_ids = ["${local.aws_account_id}"]
}
${local.microservice.locals.orchestrator == "eks" ? <<EOT
  provider "kubernetes" {
    host                   = one(values(module.eks)).cluster_endpoint
    cluster_ca_certificate = base64decode(one(values(module.eks)).cluster.certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", one(values(module.eks)).cluster.name]
    }
  }

  provider "kubectl" {
    host                   = one(values(module.eks)).cluster_endpoint
    cluster_ca_certificate = base64decode(one(values(module.eks)).cluster.certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", one(values(module.eks)).cluster.name]
    }
  }
  EOT 
: ""}
EOF
}
