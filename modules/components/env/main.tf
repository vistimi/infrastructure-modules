data "aws_iam_policy_document" "bucket_policy" {
  statement {
    principals {
      type = "Service"
      identifiers = [
        "ecs.amazonaws.com",
        "elasticloadbalancing.amazonaws.com",
      ]
    }

    actions = [
      "s3:*",
    ]

    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "aws:SourceVpce"
      values   = ["${var.vpc_id}"]
    }

    resources = [
      "arn:aws:s3:::${var.bucket_name}/*",
    ]
  }
}

module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = var.bucket_name
  acl    = "private"

  versioning = {
    enabled = true
  }

  attach_policy = true
  policy        = data.aws_iam_policy_document.bucket_policy.json

  tags = merge(var.common_tags, { Name = var.bucket_name })
}
