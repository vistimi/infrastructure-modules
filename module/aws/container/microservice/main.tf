# ------------
#     VPC
# ------------
module "vpc" {
  source = "../../../../module/aws/network/vpc"

  name       = var.common_name
  cidr_ipv4  = var.vpc.cidr_ipv4
  enable_nat = var.vpc.enable_nat

  tags = var.common_tags
}

# -----------------
#     Route53
# -----------------
// TODO: check ecs service discovery
module "route53_record" {
  source = "../../../../module/aws/network/route53/record"

  for_each = {
    for key, value in { var.route53.record.subdomain_name = var.route53 } :
    key => {}
    if var.route53 != null
  }

  zone_name      = var.route53.zone.name
  subdomain_name = var.route53.record.subdomain_name
  alias_name     = "dualstack.${module.ecs.elb.lb_dns_name}"
  alias_zone_id  = module.ecs.elb.lb_zone_id

  depends_on = [module.ecs.module.elb]
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

  common_name = var.common_name
  common_tags = var.common_tags

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
  source = "../../../../module/aws/data/bucket"

  vpc_id = module.vpc.vpc.id

  name          = var.bucket_env.name
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
