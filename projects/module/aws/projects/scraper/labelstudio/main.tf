locals {
  repository_config_vars = yamldecode(file("./repository.yml"))
  name                   = lower(join("-", compact([var.name_prefix, local.repository_config_vars.project_name, local.repository_config_vars.service_name, var.name_suffix])))

  iam = {
    scope       = var.iam.scope
    account_ids = var.iam.account_ids
    vpc_ids     = var.iam.vpc_ids
  }
}

module "bucket_label" {
  source = "../../../../../../module/aws/data/bucket"

  name          = "${local.name}-${local.repository_config_vars.bucket_label_name}"
  force_destroy = var.bucket_label.force_destroy
  versioning    = var.bucket_label.versioning
  iam           = local.iam

  tags = var.tags
}

module "kms" {
  source  = "terraform-aws-modules/kms/aws"
  version = "1.5.0"

  description = "Label Studio key usage"
  key_usage   = "ENCRYPT_DECRYPT"

  aliases = [local.name]

  tags = var.tags
}

locals {
  cidr_block = data.aws_vpc.current.cidr_block
  tiers      = concat(var.vpc.existing_tiers, ["ls-private", "ls-public"])
  # cidr_block = "10.0.0.0/16"
  # tiers      = ["ls-private", "ls-public"]
  subnets = {
    for i, tier in local.tiers :
    "${tier}" => [for az_idx in range(0, length(data.aws_availability_zones.available.names)) : cidrsubnet(local.cidr_block, 4, i * length(data.aws_availability_zones.available.names) + az_idx)]
  }
}

module "labelstudio" {
  source = "git::https://github.com/dresspeng/label-studio-terraform.git//terraform/aws/env?ref=master"

  environment = "demo"
  name        = "ls"
  region      = "eu-north-1"

  label_studio_additional_set = {
    "global.image.repository" = "heartexlabs/label-studio"
    "global.image.tag"        = "develop"
  }

  # name             = lower(var.name_suffix)
  # environment      = lower(join("-", compact([var.name_prefix, local.repository_config_vars.project_name, local.repository_config_vars.service_name])))
  # region           = local.region_name
  # instance_type    = var.labelstudio.instance_type
  # desired_capacity = var.labelstudio.desired_capacity
  # max_size         = var.labelstudio.max_size
  # min_size         = var.labelstudio.min_size

  # eks_capacity_type    = var.labelstudio.eks_capacity_type
  # ingress_namespace    = var.labelstudio.ingress_namespace
  # monitoring_namespace = var.labelstudio.monitoring_namespace
  # aws_auth_roles       = var.labelstudio.aws_auth_roles
  # aws_auth_users = concat(var.labelstudio.aws_auth_users, [
  #   # {
  #   #   userarn  = data.aws_caller_identity.current.arn
  #   #   username = regex("^arn:aws:iam::\\w+:user\\/(?P<user_name>\\w+)$", data.aws_caller_identity.current.arn).user_name
  #   #   groups = [
  #   #     "system:masters",
  #   #   ]
  #   # }
  # ])
  # aws_auth_accounts                     = var.labelstudio.aws_auth_accounts
  # label_studio_helm_chart_repo          = var.labelstudio.label_studio_helm_chart_repo
  # label_studio_helm_chart_repo_username = var.labelstudio.label_studio_helm_chart_repo_username
  # label_studio_helm_chart_repo_password = sensitive(var.labelstudio.label_studio_helm_chart_repo_password)
  # label_studio_helm_chart_name          = var.labelstudio.label_studio_helm_chart_name
  # label_studio_helm_chart_version       = var.labelstudio.label_studio_helm_chart_version
  # label_studio_docker_registry_server   = var.labelstudio.label_studio_docker_registry_server
  # label_studio_docker_registry_username = var.labelstudio.label_studio_docker_registry_username
  # label_studio_docker_registry_password = sensitive(var.labelstudio.label_studio_docker_registry_password)
  # label_studio_docker_registry_email    = var.labelstudio.label_studio_docker_registry_email
  # label_studio_additional_set           = var.labelstudio.label_studio_additional_set
  # enterprise                            = var.labelstudio.enterprise
  # deploy_label_studio                   = var.labelstudio.deploy_label_studio
  # license_literal                       = sensitive(var.labelstudio.license_literal)
  # postgresql_type                       = var.labelstudio.postgresql_type
  # postgresql_machine_type               = var.labelstudio.postgresql_machine_type
  # postgresql_database                   = var.labelstudio.postgresql_database
  # postgresql_host                       = var.labelstudio.postgresql_host
  # postgresql_port                       = var.labelstudio.postgresql_port
  # postgresql_username                   = var.labelstudio.postgresql_username
  # postgresql_password                   = sensitive(var.labelstudio.postgresql_password)
  # postgresql_ssl_mode                   = var.labelstudio.postgresql_ssl_mode
  # postgresql_tls_key_file               = var.labelstudio.postgresql_tls_key_file
  # postgresql_tls_crt_file               = var.labelstudio.postgresql_tls_crt_file
  # postgresql_ca_crt_file                = var.labelstudio.postgresql_ca_crt_file
  # redis_type                            = var.labelstudio.redis_type
  # redis_machine_type                    = var.labelstudio.redis_machine_type
  # redis_host                            = var.labelstudio.redis_host
  # redis_port                            = var.labelstudio.redis_port
  # redis_password                        = sensitive(var.labelstudio.redis_password)
  # redis_ssl_mode                        = var.labelstudio.redis_ssl_mode
  # redis_ca_crt_file                     = var.labelstudio.redis_ca_crt_file
  # redis_tls_crt_file                    = var.labelstudio.redis_tls_crt_file
  # redis_tls_key_file                    = var.labelstudio.redis_tls_key_file
  # lets_encrypt_email                    = var.labelstudio.lets_encrypt_email

  # # dns
  # create_r53_zone        = false
  # create_acm_certificate = var.labelstudio.create_acm_certificate
  # domain_name            = try(var.route53.zone.name, null)
  # record_name            = try(var.route53.record.subdomain_name, null)

  # # s3
  # predefined_s3_bucket = {
  #   name : module.bucket_label.bucket.name
  #   region : local.region_name
  #   folder : "/"
  #   kms_arn : module.kms.key_arn
  # }

  # # vpc
  # predefined_vpc_id                    = var.vpc.id
  # cluster_endpoint_public_access_cidrs = var.labelstudio.cluster_endpoint_public_access_cidrs
  # create_internet_gateway              = false
  # vpc_cidr_block                       = null
  # public_cidr_block                    = local.subnets["ls-public"]
  # private_cidr_block                   = local.subnets["ls-private"]
}

data "aws_eks_cluster" "eks" {
  name = module.labelstudio.cluster_name
}

data "aws_eks_cluster_auth" "eks" {
  name = module.labelstudio.cluster_name
}
