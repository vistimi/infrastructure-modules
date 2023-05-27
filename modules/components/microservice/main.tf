# ------------
#     ECS
# ------------
module "ecs" {
  source = "../../components/ecs"

  count = var.deployment.use_load_balancer ? 1 : 0

  common_name = var.common_name
  common_tags = var.common_tags
  vpc         = var.vpc

  use_fargate = var.deployment.use_fargate
  traffic     = var.traffic
  log         = var.log

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
  source = "terraform-aws-modules/ecr/aws"

  repository_name = var.common_name
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last ${var.ecr.image_keep_count} images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["v"],
          countType     = "imageCountMoreThan",
          countNumber   = var.ecr.image_keep_count
        },
        action = {
          type = "expire"
        }
      }
    ]
  })
  repository_force_delete         = var.ecr.force_destroy
  repository_image_tag_mutability = "MUTABLE"

  tags = var.common_tags
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
