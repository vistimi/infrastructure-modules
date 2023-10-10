include {
  path = find_in_parent_folders()
}

locals {
  microservice = read_terragrunt_config("${get_terragrunt_dir()}/microservice_override.hcl")
}

# Generate version block
generate "version_kubernetes" {
  path      = "version_kubernetes_override.tf"
  if_exists = "overwrite_terragrunt"
  contents = <<EOF
${local.microservice.locals.orchestrator == "eks" ? <<EOT
  terraform {
    required_providers {
      kubectl = {
        source  = "gavinbunney/kubectl"
        version = "= 1.14.0"
      }
      helm = {
        source  = "hashicorp/helm"
        version = "2.5.0"
      }
      kubernetes = {
        source  = "hashicorp/kubernetes"
        version = "2.0.1"
      }
    }
  }
  EOT
: ""}
EOF
}

generate "provider_kubernetes" {
  path      = "provider_kubernetes_override.tf"
  if_exists = "overwrite_terragrunt"
  contents = <<EOF
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
