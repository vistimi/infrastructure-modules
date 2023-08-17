# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION BLOCKS
# ---------------------------------------------------------------------------------------------------------------------
locals {
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
      required_version = "~> 1.4.4"

      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = "= 4.63.0"
        }
        helm = {
          source  = "hashicorp/helm"
          version = "= 2.9.0"
        }
        kubernetes = {
          source  = "hashicorp/kubernetes"
          version = "= 2.19.0"
        }
        kubectl = {
          source  = "gavinbunney/kubectl"
          version = "= 1.14.0"
        }
        tls = {
          source  = "hashicorp/tls"
          version = "= 4.0.4"
        }
        random = {
          source  = "hashicorp/random"
          version = "= 3.4.3"
        }
      }
    }
EOF
}

generate "provider" {
  path      = "provider_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
    provider "aws" {
      region = "${local.aws_account_region}"
      # allowed_account_ids = ["${local.aws_account_id}"]
    }
    provider "kubernetes" {
      host                   = data.aws_eks_cluster.eks.endpoint
      cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
      token                  = data.aws_eks_cluster_auth.eks.token
    }

    provider "kubectl" {
      host                   = data.aws_eks_cluster.eks.endpoint
      cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
      token                  = data.aws_eks_cluster_auth.eks.token
    }

    provider "helm" {
      kubernetes {
        host                   = data.aws_eks_cluster.eks.endpoint
        cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
        token                  = data.aws_eks_cluster_auth.eks.token
      }

      ## Doesn't work with alb-ingress-controller manifest
      #  experiments {
      #    manifest = true
      #  }
    }

    provider "random" {
    }
EOF
}
