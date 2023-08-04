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

resource "aws_kms_key" "objects" {
  for_each = var.encryption != null ? { "${var.name}" = {} } : {}

  description             = "KMS key is used to encrypt bucket objects"
  deletion_window_in_days = var.encryption.deletion_window_in_days

  tags = var.tags
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

  server_side_encryption_configuration = var.encryption != null ? {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = aws_kms_key.objects[var.name].arn
        sse_algorithm     = "aws:kms"
      }
    }
  } : {}

  tags = var.tags
}

module "bucket_policy" {
  source = "../../iam/resource_scope"

  scope       = var.iam.scope
  statements  = local.iam_statements
  account_ids = var.iam.account_ids
  vpc_ids     = var.iam.vpc_ids

  tags = var.tags
}

#-------------------
#   Attachments
#-------------------
data "aws_iam_policy_document" "role_attachment" {
  dynamic "statement" {
    for_each = concat(
      local.iam_statements,
      var.encryption != null ? [
        {
          actions   = ["kms:GetPublicKey", "kms:GetKeyPolicy", "kms:DescribeKey"]
          resources = ["arn:${local.partition}:s3:::${var.name}"]
          effect    = "Allow"
        },
      ] : []
    )

    content {
      actions   = statement.value.actions
      resources = statement.value.resources
      effect    = statement.value.effect
    }
  }
}

resource "aws_iam_policy" "role_attachment" {
  name = "${var.name}-role-attachment"

  policy = data.aws_iam_policy_document.role_attachment.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "role_attachment" {
  count = length(var.bucket_attachement_role_names)

  role       = var.bucket_attachement_role_names[count.index]
  policy_arn = aws_iam_policy.role_attachment.arn
}
