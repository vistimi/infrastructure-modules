locals {
  bucket_name = "${var.common_name}-env"
}

# ------------
#     ECS
# ------------
module "ecs" {
  source = "../../components/ecs-http"

  vpc_id                              = var.vpc_id
  vpc_security_group_ids              = var.vpc_security_group_ids
  common_name                         = var.common_name
  common_tags                         = var.common_tags
  listener_port                       = var.listener_port
  listener_protocol                   = var.listener_protocol
  target_port                         = var.target_port
  target_protocol                     = var.target_protocol
  ecs_logs_retention_in_days          = var.ecs_logs_retention_in_days
  ecs_task_desired_count              = var.ecs_task_desired_count
  target_capacity_cpu                 = var.target_capacity_cpu
  capacity_provider_base              = var.capacity_provider_base
  capacity_provider_weight_on_demand  = var.capacity_provider_weight_on_demand
  capacity_provider_weight_spot       = var.capacity_provider_weight_spot
  user_data                           = var.user_data
  protect_from_scale_in               = var.protect_from_scale_in
  vpc_tier                            = var.vpc_tier
  instance_type_on_demand             = var.instance_type_on_demand
  min_size_on_demand                  = var.min_size_on_demand
  max_size_on_demand                  = var.max_size_on_demand
  desired_capacity_on_demand          = var.desired_capacity_on_demand
  maximum_scaling_step_size_on_demand = var.maximum_scaling_step_size_on_demand
  minimum_scaling_step_size_on_demand = var.minimum_scaling_step_size_on_demand
  instance_type_spot                  = var.instance_type_spot
  min_size_spot                       = var.min_size_spot
  max_size_spot                       = var.max_size_spot
  desired_capacity_spot               = var.desired_capacity_spot
  maximum_scaling_step_size_spot      = var.maximum_scaling_step_size_spot
  minimum_scaling_step_size_spot      = var.minimum_scaling_step_size_spot
  ami_ssm_architecture                = var.ami_ssm_architecture
  github_organization                 = var.github_organization
  github_repository                   = var.github_repository
  github_branch                       = var.github_branch
  health_check_path                   = var.health_check_path
  account_name                        = var.account_name
  account_region                      = var.account_region

  task_definition_arn = aws_ecs_task_definition.service.arn
}

# Policies
data "aws_iam_policy" "aws_ec2_full_access_policy" {
  name = "AmazonEC2FullAccess"
}

data "aws_iam_policy" "aws_ecs_full_access_policy" {
  name = "AmazonECS_FullAccess"
}

data "aws_iam_policy" "aws_ecs_task_execution_role_policy" {
  name = "AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ecs_task_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "ecs_task_s3_role_policy" {
  name = var.ecs_task_container_s3_env_policy_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["s3:GetBucketLocation", "s3:ListBucket"]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::${local.bucket_name}",
      },
      {
        Action   = ["s3:GetObject"]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::${local.bucket_name}/*",
      },
    ]
  })
}

# The Amazon Resource Name (ARN) of the task execution role that grants the Amazon ECS container agent permission to make AWS API calls on your behalf.
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html
resource "aws_iam_role" "ecs_task_execution_role" {
  name = var.ecs_execution_role_name

  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role_policy.json
  managed_policy_arns = [
    data.aws_iam_policy.aws_ecs_task_execution_role_policy.arn,
    aws_iam_policy.ecs_task_s3_role_policy.arn
  ]

  tags = var.common_tags
}

# The short name or full Amazon Resource Name (ARN) of the AWS Identity and Access Management role that grants containers in the task permission to call AWS APIs on your behalf.
resource "aws_iam_role" "ecs_task_container_role" {
  name = var.ecs_task_container_role_name

  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role_policy.json
  managed_policy_arns = [
    data.aws_iam_policy.aws_ec2_full_access_policy.arn,
    data.aws_iam_policy.aws_ecs_full_access_policy.arn,
    aws_iam_policy.ecs_task_s3_role_policy.arn
  ]

  tags = var.common_tags
}


# ------------------------
#     S3 env
# ------------------------
module "s3_env" {
  source        = "../../components/env"
  account_id    = var.account_id
  bucket_name   = local.bucket_name
  common_tags   = var.common_tags
  vpc_id        = var.vpc_id
  force_destroy = var.force_destroy
  source_arns   = [module.ecs.ecs_service_arn]
}

# ------------------------
#     Task definition
# ------------------------
resource "aws_ecs_task_definition" "service" {

  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_container_role.arn
  memory                   = var.ecs_task_definition_memory
  cpu                      = var.ecs_task_definition_cpu
  family                   = var.common_name
  requires_compatibilities = ["EC2"]

  container_definitions = jsonencode([
    {
      name = var.common_name
      environmentFiles : [
        {
          "value" : "arn:aws:s3:::${var.common_name}-env/${var.env_file_name}",
          "type" : "s3"
        }
      ]
      portMappings : var.port_mapping
      memory            = var.ecs_task_definition_memory
      memoryReservation = var.ecs_task_definition_memory_reservation
      cpu               = var.ecs_task_definition_cpu

      image     = "${var.account_id}.dkr.ecr.${var.account_region}.amazonaws.com/${var.common_name}:${var.ecs_task_definition_image_tag}"
      essential = true
    }
  ])
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
        description  = "Keep last ${var.repository_image_keep_count} images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["v"],
          countType     = "imageCountMoreThan",
          countNumber   = var.repository_image_keep_count
        },
        action = {
          type = "expire"
        }
      }
    ]
  })
  repository_force_delete         = var.force_destroy
  repository_image_tag_mutability = "MUTABLE"

  tags = var.common_tags
}

# ------------------------
#     Github secrets
# ------------------------
// FIXME: make it work for secret env or move this logic elsewhere
// TODO: make ECS depend on those secrets
# data "github_repository" "repo" {
#   full_name = "${var.github_organization}/${var.github_repository}"
# }

# resource "github_repository_environment" "repo_environment" {
#   repository  = var.github_repository
#   environment = lower(var.account_name)
# }

# resource "github_actions_environment_secret" "aws_access_key" {
#   repository      = var.github_repository
#   environment     = github_repository_environment.repo_environment.environment
#   secret_name     = "AWS_ACCESS_KEY_ID"
#   plaintext_value = var.aws_access_key
# }

# resource "github_actions_environment_secret" "aws_secret_key" {
#   repository      = var.github_repository
#   environment     = github_repository_environment.repo_environment.environment
#   secret_name     = "AWS_SECRET_ACCESS_KEY"
#   plaintext_value = var.aws_secret_key
# }
