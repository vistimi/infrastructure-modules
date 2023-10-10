data "aws_region" "current" {}
data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  dns_suffix = data.aws_partition.current.dns_suffix // amazonaws.com
  partition  = data.aws_partition.current.partition  // aws
  region     = data.aws_region.current.name

  repository_service = var.privacy == "public" ? "ecr-public" : var.privacy == "private" ? "ecr" : null

  repository_arn = var.privacy == "public" ? [
    "arn:${local.partition}:${local.repository_service}::${local.account_id}:repository/${var.name}"
    ] : var.privacy == "private" ? [
    "arn:${local.partition}:${local.repository_service}:${local.region}:${local.account_id}:repository/${var.name}"
  ] : null

  iam_statements = [
    {
      actions = [
        "${local.repository_service}:GetAuthorizationToken",
        "${local.repository_service}:BatchCheckLayerAvailability",
        "${local.repository_service}:GetDownloadUrlForLayer",
        "${local.repository_service}:BatchGetImage",
      ]
      resources = [loca.repository_arn]
      effect    = "Allow"
    }
  ]
}

module "bucket_policy" {
  source = "../../iam/resource_scope"

  scope       = var.iam.scope
  statements  = local.iam_statements
  account_ids = var.iam.account_ids
  vpc_ids     = var.iam.vpc_ids

  tags = var.tags
}

module "ecr" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "1.6.0"

  repository_name   = var.name
  create_repository = true

  # Registry Policy
  create_repository_policy = true
  repository_policy        = module.bucket_policy.json

  create_lifecycle_policy = true
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last ${var.image_keep_count} images",
        selection = {
          tagStatus   = "any",
          countType   = "imageCountMoreThan",
          countNumber = var.image_keep_count
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

#-------------------
#   Attachments
#-------------------
resource "aws_iam_policy" "role_attachment" {
  name = "${var.name}-role-attachment"

  policy = module.bucket_policy.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "role_attachment" {
  count = length(var.repository_attachement_role_names)

  role       = var.repository_attachement_role_names[count.index]
  policy_arn = aws_iam_policy.role_attachment.arn
}
