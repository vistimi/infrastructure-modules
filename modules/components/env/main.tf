locals {
  identifiers = [
    "ecs.amazonaws.com",
    "elasticloadbalancing.amazonaws.com",
    "ecs.application-autoscaling.amazonaws.com"
  ]
}

data "aws_iam_policy_document" "bucket_policy" {
  # statement {
  #   principals {
  #     type        = "Service"
  #     identifiers = local.identifies
  #   }

  #   actions = [
  #     "s3:GetObject"
  #   ]

  #   condition {
  #     test     = "ForAnyValue:StringEquals"
  #     variable = "aws:SourceVpce"
  #     values   = ["${var.vpc_id}"]
  #   }

  #   resources = [
  #     "arn:aws:s3:::${var.bucket_name}/*",
  #   ]
  # }

  statement {
    principals {
      type = "AWS"
      # identifiers = var.source_arns
      identifiers = ["*"]
    }

    actions = ["s3:GetBucketLocation", "s3:ListBucket"]

    resources = [
      "arn:aws:s3:::${var.bucket_name}",
    ]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = var.source_arns
    }
  }

  statement {
    principals {
      type = "AWS"
      # identifiers = var.source_arns
      identifiers = ["*"]
    }

    actions = ["s3:GetObject"]

    resources = [
      "arn:aws:s3:::${var.bucket_name}/*",
    ]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = var.source_arns
    }
  }
}

module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = var.bucket_name
  # acl    = "private"

  versioning = {
    enabled = true
  }

  attach_policy = true
  policy        = data.aws_iam_policy_document.bucket_policy.json
  force_destroy = var.force_destroy

  tags = merge(var.common_tags, { Name = var.bucket_name })
}
