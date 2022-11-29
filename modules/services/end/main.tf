# ------------
#     ECS
# ------------
module "ecs_cluster" {
  source = "../../components/ecs"

  vpc_id                     = var.vpc_id
  common_name                = var.common_name
  common_tags                = var.common_tags
  listener_port              = var.listener_port
  listener_protocol          = var.listener_protocol
  target_port                = var.target_port
  target_protocol            = var.target_protocol
  task_definition_arn        = aws_ecs_task_definition.service.arn
  ecs_logs_retention_in_days = var.ecs_logs_retention_in_days
  user_data                  = var.user_data
  protect_from_scale_in      = var.protect_from_scale_in
  vpc_tier                   = var.vpc_tier
  instance_type_on_demand    = var.instance_type_on_demand
  min_size_on_demand         = var.min_size_on_demand
  max_size_on_demand         = var.max_size_on_demand
  desired_capacity_on_demand = var.desired_capacity_on_demand
  instance_type_spot         = var.instance_type_spot
  min_size_spot              = var.min_size_spot
  max_size_spot              = var.max_size_spot
  desired_capacity_spot      = var.desired_capacity_spot
}

# ECS Roles and policies
# used in task definition template
data "aws_iam_policy" "aws_ec2_full_access" {
  name = "AmazonEC2FullAccess"
}

data "aws_iam_policy" "aws_ecs_full_access" {
  name = "AmazonECS_FullAccess"
}

data "aws_iam_policy" "aws_ecs_task_execution_role_policy" {
  name = "AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ec2_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# The Amazon Resource Name (ARN) of the task execution role that grants the Amazon ECS container agent permission to make AWS API calls on your behalf.
resource "aws_iam_role" "ecs_execution_role" {
  name = var.ecs_execution_role_name

  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role_policy.json
  managed_policy_arns = [
    data.aws_iam_policy.aws_ecs_task_execution_role_policy.arn
  ]

  tags = var.common_tags
}

# The short name or full Amazon Resource Name (ARN) of the AWS Identity and Access Management role that grants containers in the task permission to call AWS APIs on your behalf.
resource "aws_iam_role" "ecs_task_container_role" {
  name = var.ecs_task_container_role_name

  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role_policy.json
  managed_policy_arns = [
    data.aws_iam_policy.aws_ec2_full_access.arn,
    data.aws_iam_policy.aws_ecs_full_access.arn,
    # data.aws_iam_policy.aws_ecs_task_execution_role_policy.arn
  ]

  tags = var.common_tags
}

# ------------------------
#     Task definition
# ------------------------
# S3 bucket for env file
module "s3_env" {
  source      = "../../components/env"
  aws_region  = var.account_region
  bucket_name = var.bucket_env_name
  common_tags = var.common_tags
  vpc_id      = var.vpc_id
}

# ECS task definition
resource "aws_ecs_task_definition" "service" {

  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_container_role.arn
  memory                   = var.ecs_task_definition_memory
  cpu                      = var.ecs_task_definition_cpu
  family                   = var.ecs_task_definition_family_name
  requires_compatibilities = ["EC2"]

  container_definitions = jsonencode([
    {
      name = var.ecs_task_container_name
      environmentFiles : [
        {
          "value" : "arn:aws:s3:::${var.bucket_env_name}/${var.env_file_name}",
          "type" : "s3"
        }
      ]
      portMappings : var.port_mapping
      memory            = var.ecs_task_definition_memory
      memoryReservation = var.ecs_task_definition_memory_reservation
      cpu               = var.ecs_task_definition_cpu

      image     = "${var.account_id}.dkr.ecr.${var.account_region}.amazonaws.com/${var.repository_name}:f5539f74d7486ddaf99608ea704ce585b4c375d9"
      essential = true
    }
  ])
}

# ------------
#     ECR
# ------------
module "ecr" {
  source = "terraform-aws-modules/ecr/aws"

  repository_name                   = var.common_name
  # repository_read_write_access_arns = [aws_iam_role.ecr_execution_role.arn]
  # repository_read_access_arns       = var.repository_read_access_arns
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last ${var.repository_image_count} images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["v"],
          countType     = "imageCountMoreThan",
          countNumber   = var.repository_image_count
        },
        action = {
          type = "expire"
        }
      }
    ]
  })
  repository_force_delete = var.repository_force_delete

  tags = var.common_tags
}

# # ECR roles and policies
# # https://docs.aws.amazon.com/AmazonECR/latest/userguide/security-iam-awsmanpol.html
# data "aws_iam_policy" "aws_ec2_container_registry_full_access" {
#   name = "AmazonEC2ContainerRegistryFullAccess"
# }

# data "aws_iam_policy_document" "ecr_assume_role_policy" {
#   statement {
#     actions = ["sts:AssumeRole"]

#     principals {
#       # type        = "Service"
#       # identifiers = ["ec2.amazonaws.com"]
#       type        = "iam:AWSServiceName"
#       identifiers = ["replication.ecr.amazonaws.com"]
#     }
#   }
# }

# # Role ARN for read write access for container registry for this user
# resource "aws_iam_role" "ecr_execution_role" {
#   name = "ecr-task-execution-role"

#   assume_role_policy = data.aws_iam_policy_document.ecr_assume_role_policy.json
#   managed_policy_arns = [
#     data.aws_iam_policy.aws_ec2_container_registry_full_access.arn
#   ]

#   tags = var.common_tags
# }

# ------------------------
#     Github secrets
# ------------------------
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

# ------------------------
#     MongoDB
# ------------------------
module "mongodb" {
  source = "../../data/mongodb"

  common_name            = var.common_name
  vpc_id                 = var.vpc_id
  vpc_security_group_ids = var.vpc_security_group_ids
  common_tags            = var.common_tags
  force_destroy          = var.force_destroy
  ami_id                 = var.ami_id
  instance_type          = var.instance_type
  user_data_path         = var.user_data_path
  user_data_args         = var.user_data_args
  bastion                = false
  aws_access_key         = var.aws_access_key
  aws_secret_key         = var.aws_secret_key
}
