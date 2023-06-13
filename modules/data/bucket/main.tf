data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  dns_suffix = data.aws_partition.current.dns_suffix // amazonaws.com
}

data "aws_iam_policy_document" "bucket_policy" {
  statement {
    actions = ["s3:GetBucketLocation", "s3:ListBucket"]

    resources = [
      "arn:aws:s3:::${var.name}",
    ]

    principals {
      type = "Service"
      identifiers = [
        "ec2.${local.dns_suffix}",
      ]
    }

    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "aws:SourceVpce"
      values   = ["${var.vpc_id}"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }

  statement {
    actions = ["s3:GetObject"]

    resources = [
      "arn:aws:s3:::${var.name}/*",
    ]

    principals {
      type = "Service"
      identifiers = [
        "ec2.${local.dns_suffix}",
      ]
    }

    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "aws:SourceVpce"
      values   = ["${var.vpc_id}"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }

  #     "kms:GetPublicKey",
  #     "kms:GetKeyPolicy",
  #     "kms:DescribeKey"
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
  policy        = data.aws_iam_policy_document.bucket_policy.json
  force_destroy = var.force_destroy

  # control_object_ownership = true
  # object_ownership         = "ObjectWriter"

  tags = merge(var.common_tags, { Name = var.name })
}
