locals {
  tags = merge(var.tags, { VpcId = "${var.vpc.id}" })
}

# ------------
#     ECS
# ------------
module "ecs" {
  source = "../../../../module/aws/container/ecs"

  vpc = var.vpc

  route53 = var.route53

  name = var.name

  service  = var.ecs.service
  traffics = var.ecs.traffics

  task_definition = merge(var.ecs.task_definition,
    var.bucket_env != null ? {
      env_file = {
        bucket_name = one(module.bucket_env[*].bucket.name)
        file_name   = var.bucket_env.file_key
      }
  } : {})

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
  for_each = var.bucket_env != null ? { "${var.bucket_env.name}" = {} } : {}

  key                    = var.bucket_env.file_key
  bucket                 = module.bucket_env[each.key].bucket.id
  source                 = var.bucket_env.file_path
  server_side_encryption = "aws:kms"
}
