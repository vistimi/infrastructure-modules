# ------------
#     ECS
# ------------
module "ecs" {
  source = "../../components/ecs"

  common_name = var.common_name
  common_tags = var.common_tags
  vpc         = var.vpc

  service = var.ecs.service
  traffic = var.ecs.traffic
  log     = var.ecs.log

  capacity_provider = var.ecs.capacity_provider
  task_definition   = var.ecs.task_definition

  fargate = var.ecs.fargate
  ec2     = var.ecs.ec2
}

# ------------
#     ECR
# ------------
module "ecr" {
  source           = "../../components/ecr"
  common_name      = var.common_name
  common_tags      = var.common_tags
  vpc_id           = var.vpc.id
  force_destroy    = var.ecr.force_destroy
  image_keep_count = var.ecr.image_keep_count
}

# ------------------------
#     Bucket env
# ------------------------
module "bucket_env" {
  source        = "../../data/bucket"
  name          = var.bucket_env.name
  common_tags   = var.common_tags
  vpc_id        = var.vpc.id
  force_destroy = var.bucket_env.force_destroy
  versioning    = var.bucket_env.versioning
}
