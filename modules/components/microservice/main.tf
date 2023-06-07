# ------------
#     ECS
# ------------
module "ecs" {
  source = "../../components/ecs"

  common_name = var.common_name
  common_tags = var.common_tags
  vpc         = var.vpc

  deployment = var.deployment
  traffic    = var.traffic
  log        = var.log

  user_data         = var.user_data
  instance          = var.instance
  capacity_provider = var.capacity_provider
  autoscaling_group = var.autoscaling_group

  task_definition            = var.task_definition
  service_task_desired_count = var.service_task_desired_count
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
  bucket_name   = var.bucket_env.name
  common_tags   = var.common_tags
  vpc_id        = var.vpc.id
  force_destroy = var.bucket_env.force_destroy
  versioning    = var.bucket_env.versioning
}
