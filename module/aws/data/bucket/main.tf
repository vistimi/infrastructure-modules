data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  dns_suffix = data.aws_partition.current.dns_suffix // amazonaws.com
  partition  = data.aws_partition.current.partition  // aws

  iam_statements = [
    {
      actions   = ["s3:GetBucketLocation", "s3:ListBucket"]
      resources = ["arn:${local.partition}:s3:::${var.name}"]
      effect    = "Allow"
    },
    {
      actions   = ["s3:GetObject"]
      resources = ["arn:${local.partition}:s3:::${var.name}/*"]
      effect    = "Allow"
    }
  ]
}

// TODO: add encryption
module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "3.11.0"

  bucket = var.name
  # acl    = "private"  # no need if policy is tight

  versioning = var.versioning ? {
    enabled = true
  } : {}

  attach_policy = true
  policy        = module.bucket_policy.json
  force_destroy = var.force_destroy

  # control_object_ownership = true
  # object_ownership         = "ObjectWriter"

  tags = merge(var.tags, { Name = var.name })
}

module "bucket_policy" {
  source = "../../iam/policy_document"

  scope               = var.iam.scope
  statements          = local.iam_statements
  principals_services = ["ec2"]
  account_ids         = var.iam.account_ids
  vpc_ids             = concat(var.iam.vpc_ids, [var.vpc_id])
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
  for_each = { for role_name in var.bucket_attachement_role_names : role_name => {} }

  role       = each.key
  policy_arn = aws_iam_policy.role_attachment.arn
}
