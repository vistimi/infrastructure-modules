# ------------
#     VPC
# ------------
module "vpc" {
  source     = "../../../../module/aws/vpc"
  name       = var.common_name
  cidr_ipv4  = var.vpc.cidr_ipv4
  enable_nat = var.vpc.enable_nat

  tags = var.common_tags
}

# ------------
#     ECS
# ------------
module "ecs" {
  source = "../../../../module/aws/container/ecs"

  common_name = var.common_name
  common_tags = var.common_tags
  vpc = {
    id                 = module.vpc.vpc.vpc_id
    security_group_ids = [module.vpc.vpc.default_security_group_id]
    tier               = var.vpc.tier
  }

  service = var.ecs.service
  traffic = var.ecs.traffic
  log     = var.ecs.log

  task_definition = var.ecs.task_definition

  fargate = var.ecs.fargate
  ec2     = var.ecs.ec2
}

# ------------------------
#     Bucket env
# ------------------------
module "bucket_env" {
  source        = "../../../../module/aws/data/bucket"
  name          = var.bucket_env.name
  vpc_id        = module.vpc.vpc.vpc_id
  force_destroy = var.bucket_env.force_destroy
  versioning    = var.bucket_env.versioning

  tags = var.common_tags
}

resource "aws_s3_object" "env" {
  key                    = var.bucket_env.file_key
  bucket                 = module.bucket_env.bucket.id
  source                 = var.bucket_env.file_path
  server_side_encryption = "aws:kms"
}
