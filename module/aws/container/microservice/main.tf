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

  service = var.ecs.service
  traffic = var.ecs.traffic
  log     = var.ecs.log

  task_definition = var.ecs.task_definition

  fargate = var.ecs.fargate
  ec2     = var.ecs.ec2

  tags = local.tags
}

# ------------------------
#     Bucket env
# ------------------------
module "bucket_env" {
  source = "../../../../module/aws/data/bucket"

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
  key                    = var.bucket_env.file_key
  bucket                 = module.bucket_env.bucket.id
  source                 = var.bucket_env.file_path
  server_side_encryption = "aws:kms"
}
