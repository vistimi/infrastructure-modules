data "aws_region" "current" {}
data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  dns_suffix = data.aws_partition.current.dns_suffix // amazonaws.com
  partition  = data.aws_partition.current.partition  // aws
  region     = data.aws_region.current.name
}

module "ecr" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "1.6.0"

  repository_name   = var.name
  create_repository = true

  # Registry Policy
  create_repository_policy = true
  repository_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service : [
            "ec2.${local.dns_suffix}",
            // FIXME: remove below
            "ecs.${local.dns_suffix}",
            "ecs-tasks.${local.dns_suffix}",
            "ecs.application-autoscaling.${local.dns_suffix}",
            "ec2.application-autoscaling.${local.dns_suffix}",
            "application-autoscaling.${local.dns_suffix}",
            "autoscaling.${local.dns_suffix}",
          ]
        },
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
        ],
        Resource = [
          "arn:${local.partition}:ecr:${local.region}:${local.account_id}:repository/${var.name}"
        ],
        Condition = {
          "ForAnyValue:StringEquals" : {
            "aws:SourceVpce" : ["${var.vpc_id}"]
          },
          "StringEquals" : {
            "aws:SourceAccount" : [local.account_id],
          },
        }
      },
    ]
  })

  create_lifecycle_policy = true
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last ${var.image_keep_count} images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["v"],
          countType     = "imageCountMoreThan",
          countNumber   = var.image_keep_count
        },
        action = {
          type = "expire"
        }
      }
    ]
  })
  repository_force_delete         = var.force_destroy
  repository_image_tag_mutability = "MUTABLE"

  tags = var.tags
}
