# ------------
#     VPC
# ------------
module "vpc" {
  source = "../../../../module/aws/network/vpc"

  name       = var.name
  cidr_ipv4  = var.vpc.cidr_ipv4
  enable_nat = var.vpc.enable_nat
  tier       = var.vpc.tier

  tags = var.tags
}

locals {
  tags = merge(var.tags, { VpcId = "${module.vpc.vpc.id}" })
}

# ------------
#     ECS
# ------------
module "ecs" {
  source = "../../../../module/aws/container/ecs"

  vpc = {
    id                 = module.vpc.vpc.id
    security_group_ids = [module.vpc.default.security_group_id]
    tier               = var.vpc.tier
  }

  route53 = var.route53

  name = var.name

  service  = var.ecs.service
  traffics = var.ecs.traffics
  log      = var.ecs.log

  task_definition = var.ecs.task_definition
  # merge(var.ecs.task_definition,
  #   try({
  #     env_file = {
  #       bucket_name = var.bucket_env.name
  #       file_name   = var.bucket_env.file_key
  #     }
  # }, {}))

  fargate = var.ecs.fargate
  ec2     = var.ecs.ec2

  tags = local.tags
}

# ------------------------
#     Bucket env
# ------------------------
module "bucket_env" {
  source = "../../../../module/aws/data/bucket"

  for_each = var.bucket_env != null ? { "${var.bucket_env.name}" = {} } : {}

  name          = var.bucket_env.name
  force_destroy = var.bucket_env.force_destroy
  versioning    = var.bucket_env.versioning
  encryption = {
    enable = true
  }
  iam = {
    scope       = var.iam.scope
    account_ids = var.iam.account_ids
    vpc_ids     = var.iam.vpc_ids
  }

  tags = local.tags
}

resource "aws_s3_object" "env" {
  for_each = var.bucket_env != null ? { "${var.bucket_env.name}" = {} } : {}

  key                    = var.bucket_env.file_key
  bucket                 = module.bucket_env[each.key].bucket.id
  source                 = var.bucket_env.file_path
  server_side_encryption = "aws:kms"
}
