locals {
  tags = merge(var.tags, { VpcId = "${var.vpc.id}" })
}

module "ecs" {
  source = "../../../../module/aws/container/ecs"

  for_each = var.container.ecs != null ? { "${var.name}" = {} } : {}

  name     = var.name
  vpc      = var.vpc
  route53  = var.route53
  traffics = var.container.traffics
  ecs = {
    service = {
      task    = merge(var.container.group.deployment, var.container.ecs.service.task, { container = merge(var.container.group.deployment.container, var.container.ecs.service.task.container) })
      ec2     = var.container.group.ec2
      fargate = var.container.group.fargate
    }
  }

  tags = local.tags
}

module "eks" {
  source = "../../../../module/aws/container/eks"

  name     = var.name
  vpc      = var.vpc
  route53  = var.route53
  traffics = var.container.traffics
  eks = merge(
    {
      create = var.container.eks != null ? true : false
      group  = var.container.group
    },
    var.container.eks
  )

  tags = local.tags
}

# ------------------------
#     Bucket env
# ------------------------
module "bucket_env" {
  source = "../../../../module/aws/data/bucket"

  for_each = var.bucket_env != null ? { unique = {} } : {}

  name          = join("-", [var.name, var.bucket_env.name])
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
  for_each = var.bucket_env != null ? { unique = {} } : {}

  key                    = var.bucket_env.file_key
  bucket                 = module.bucket_env[each.key].bucket.name
  source                 = var.bucket_env.file_path
  server_side_encryption = "aws:kms"
}
