# ECS
module "ecs_cluster" {
  source = "../../components/ecs"

  vpc_id                     = var.vpc_id
  common_name                = var.common_name
  tags                       = var.common_tags
  listener_port              = var.listener_port
  listener_protocol          = var.listener_protocol
  target_port                = var.target_port
  target_protocol            = var.target_protocol
  task_definition_arn        = var.task_definition_arn
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

# # ECS Roles and policies
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

# # The Amazon Resource Name (ARN) of the task execution role that grants the Amazon ECS container agent permission to make AWS API calls on your behalf.
resource "aws_iam_role" "ecs_execution_role" {
  name = var.ecs_execution_role_name

  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role_policy.json
  managed_policy_arns = [
    data.aws_iam_policy.aws_ecs_task_execution_role_policy.arn
  ]

  tags = var.common_tags
}

# # The short name or full Amazon Resource Name (ARN) of the AWS Identity and Access Management role that grants containers in the task permission to call AWS APIs on your behalf.
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

# Github secrets
data "github_repository" "repo" {
  full_name = "${var.gh_organization}/${var.gh_repository}"
}

resource "github_repository_environment" "repo_environment" {
  repository       = data.github_repository.repo.name
  environment      = var.aws_account_name
}

resource "github_actions_environment_secret" "aws_access_key" {
  repository       = data.github_repository.repo.name
  environment      = github_repository_environment.repo_environment.environment
  secret_name      = "AWS_ACCESS_KEY_ID"
  plaintext_value  = var.aws_access_key
}

resource "github_actions_environment_secret" "aws_secret_key" {
  repository       = data.github_repository.repo.name
  environment      = github_repository_environment.repo_environment.environment
  secret_name      = "AWS_SECRET_ACCESS_KEY"
  plaintext_value  = var.aws_secret_key
}

# # ECR
# # TODO: replace GH workflow ECR creation with terraform
# module "ecr" {
#   source = "terraform-aws-modules/ecr/aws"

#   repository_name                   = var.common_name
#   repository_read_write_access_arns = merge(var.repository_read_write_access_arns, [])
#   repository_read_access_arns       = var.repository_read_access_arns
#   repository_lifecycle_policy = jsonencode({
#     rules = [
#       {
#         rulePriority = 1,
#         description  = "Keep last ${var.repository_image_count} images",
#         selection = {
#           tagStatus     = "tagged",
#           tagPrefixList = ["v"],
#           countType     = "imageCountMoreThan",
#           countNumber   = var.repository_image_count
#         },
#         action = {
#           type = "expire"
#         }
#       }
#     ]
#   })
#   repository_force_delete = var.repository_force_delete

#   tags = var.common_tags
# }

# # ECR roles and policies
# # https://docs.aws.amazon.com/AmazonECR/latest/userguide/security-iam-awsmanpol.html
# data "aws_iam_policy" "aws_ec2_container_registry_full_access" {
#   name = "AmazonEC2ContainerRegistryFullAccess"
# }

# data "aws_iam_policy_document" "ecr_assume_role_policy" {
#   statement {
#     actions = ["sts:AssumeRole"]

#     principals {
#       type        = "Service"
#       identifiers = ["ecr.amazonaws.com"]
#     }
#   }
# }

# # Role ARN for read write access for container registry for this user
# resource "aws_iam_role" "ecs_execution_role" {
#   name = "ecs-task-execution-role"

#   assume_role_policy = data.aws_iam_policy_document.ecr_assume_role_policy.json
#   managed_policy_arns = [
#     data.aws_iam_policy.aws_ec2_container_registry_full_access.arn
#   ]

#   tags = var.common_tags
# }


# ECS task definition
# generated in the version controller, e.g. Github