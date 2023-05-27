resource "aws_iam_role" "ec2" {
  name = "${var.bucket_name}-ec2"
  tags = var.common_tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Effect = "Allow",
      },
    ]
  })
}

data "aws_iam_policy_document" "bucket_policy" {
  statement {
    actions = ["s3:GetBucketLocation", "s3:ListBucket"]

    resources = [
      "arn:aws:s3:::${var.bucket_name}",
    ]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.ec2.arn]
    }

    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "aws:SourceVpce"
      values   = ["${var.vpc_id}"]
    }
  }

  statement {
    actions = ["s3:GetObject"]

    resources = [
      "arn:aws:s3:::${var.bucket_name}/*",
    ]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.ec2.arn]
    }

    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "aws:SourceVpce"
      values   = ["${var.vpc_id}"]
    }
  }

  # statement {
  #   actions = [
  #     "kms:GetPublicKey",
  #     "kms:GetKeyPolicy",
  #     "kms:DescribeKey"
  #   ]

  #   resources = [
  #     "*",
  #   ]

  #   principals {
  #     type        = "AWS"
  #     identifiers = ["*"]
  #   }

  #   condition {
  #     test     = "ForAnyValue:StringEquals"
  #     variable = "aws:SourceVpce"
  #     values   = ["${var.vpc_id}"]
  #   }
  # }
}

// TODO: add encryption
module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = var.bucket_name
  # acl    = "private"

  versioning = var.versioning ? {
    enabled = true
  } : {}

  attach_policy = true
  policy        = data.aws_iam_policy_document.bucket_policy.json
  force_destroy = var.force_destroy

  # control_object_ownership = true
  # object_ownership         = "ObjectWriter"

  tags = merge(var.common_tags, { Name = var.bucket_name })
}
