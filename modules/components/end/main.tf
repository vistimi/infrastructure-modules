# ------------
#     ECS
# ------------
module "ecs_cluster" {
  source = "../../components/ecs"

  vpc_id                        = var.vpc_id
  common_name                   = var.common_name
  common_tags                   = var.common_tags
  listener_port                 = var.listener_port
  listener_protocol             = var.listener_protocol
  target_port                   = var.target_port
  target_protocol               = var.target_protocol
  task_definition_arn           = aws_ecs_task_definition.service.arn
  ecs_logs_retention_in_days    = var.ecs_logs_retention_in_days
  user_data                     = var.user_data
  protect_from_scale_in         = var.protect_from_scale_in
  vpc_tier                      = var.vpc_tier
  instance_type_on_demand       = var.instance_type_on_demand
  min_size_on_demand            = var.min_size_on_demand
  max_size_on_demand            = var.max_size_on_demand
  desired_capacity_on_demand    = var.desired_capacity_on_demand
  instance_type_spot            = var.instance_type_spot
  min_size_spot                 = var.min_size_spot
  max_size_spot                 = var.max_size_spot
  desired_capacity_spot         = var.desired_capacity_spot
  github_workflow_file_name_ecs = var.github_workflow_file_name_ecs
  github_workflow_name_ecs      = var.github_workflow_name_ecs

  depends_on = [module.s3_env, module.ecr]
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
  bucket_name = "${var.common_name}-env"
  common_tags = var.common_tags
  vpc_id      = var.vpc_id

  provisioner "local-exec" {
    command = "/bin/bash gh_wf_ecr.sh GH_WF_FILE=$GH_WF_FILE GH_WF_NAME=$GH_WF_NAME GH_ORG=$GH_ORG GH_REPO=$GH_REPO GH_BRANCH=$GH_BRANCH AWS_ACCOUNT_NAME=$AWS_ACCOUNT_NAME AWS_REGION=$AWS_REGION COMMON_NAME=$COMMON_NAME MONGO_IP=$MONGO_IP"
    environment = {
      GH_WF_FILE       = var.github_workflow_file_name_env
      GH_WF_NAME       = var.github_workflow_name_env
      GH_ORG           = var.github_organization
      GH_REPO          = var.github_repository
      GH_BRANCH        = var.github_branch
      AWS_ACCOUNT_NAME = var.account_name
      AWS_REGION       = var.account_region
      COMMON_NAME      = var.common_name
      MONGO_IP         = var.mongodb_ipv4
    }
  }
}

# ECS task definition
resource "aws_ecs_task_definition" "service" {

  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
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

      image     = "${var.account_id}.dkr.ecr.${var.account_region}.amazonaws.com/${var.common_name}:f5539f74d7486ddaf99608ea704ce585b4c375d9"
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

  provisioner "local-exec" {
    command = "/bin/bash gh_wf_ecr.sh GH_WF_FILE=$GH_WF_FILE GH_WF_NAME=$GH_WF_NAME GH_ORG=$GH_ORG GH_REPO=$GH_REPO GH_BRANCH=$GH_BRANCH AWS_ACCOUNT_NAME=$AWS_ACCOUNT_NAME AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID AWS_REGION=$AWS_REGION COMMON_NAME=$COMMON_NAME"
    environment = {
      GH_WF_FILE       = var.github_workflow_file_name_ecr
      GH_WF_NAME       = var.github_workflow_name_ecr
      GH_ORG           = var.github_organization
      GH_REPO          = var.github_repository
      GH_BRANCH        = var.github_branch
      AWS_ACCOUNT_NAME = var.account_name
      AWS_ACCOUNT_ID   = var.account_id
      AWS_REGION       = var.account_region
      COMMON_NAME      = var.common_name
    }
  }
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
