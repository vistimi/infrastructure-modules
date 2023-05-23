# resource "aws_iam_role" "ec2" {
#   name = "${var.table_name}-ec2"
#   tags = var.common_tags

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Action = "sts:AssumeRole",
#         Principal = {
#           Service = "ec2.amazonaws.com"
#         },
#         Effect = "Allow",
#       },
#     ]
#   })
# }

# data "aws_iam_policy_document" "bucket_policy" {
#   statement {
#     actions = ["s3:GetBucketLocation", "s3:ListBucket"]

#     resources = [
#       "arn:aws:s3:::${var.bucket_name}",
#     ]

#     principals {
#       type        = "AWS"
#       identifiers = [aws_iam_role.ec2.arn]
#     }

#     condition {
#       test     = "ForAnyValue:StringEquals"
#       variable = "aws:SourceVpce"
#       values   = ["${var.vpc_id}"]
#     }
#   }

#   statement {
#     actions = ["s3:GetObject"]

#     resources = [
#       "arn:aws:s3:::${var.bucket_name}/*",
#     ]

#     principals {
#       type        = "AWS"
#       identifiers = [aws_iam_role.ec2.arn]
#     }

#     condition {
#       test     = "ForAnyValue:StringEquals"
#       variable = "aws:SourceVpce"
#       values   = ["${var.vpc_id}"]
#     }
#   }

#   # statement {
#   #   actions = [
#   #     "kms:GetPublicKey",
#   #     "kms:GetKeyPolicy",
#   #     "kms:DescribeKey"
#   #   ]

#   #   resources = [
#   #     "*",
#   #   ]

#   #   principals {
#   #     type        = "AWS"
#   #     identifiers = ["*"]
#   #   }

#   #   condition {
#   #     test     = "ForAnyValue:StringEquals"
#   #     variable = "aws:SourceVpce"
#   #     values   = ["${var.vpc_id}"]
#   #   }
#   # }
# }

module "dynamodb_table" {
  source = "terraform-aws-modules/dynamodb-table/aws"

  name = var.table_name

  # TODO: handle no sort key
  hash_key  = var.primary_key_name
  range_key = var.sort_key_name
  attributes = [
    {
      name = var.primary_key_name
      type = var.primary_key_type
    },
    {
      name = var.sort_key_name
      type = var.sort_key_type
    },
  ]

  billing_mode        = "PROVISIONED"
  read_capacity       = 5
  write_capacity      = 5
  autoscaling_enabled = var.autoscaling

  autoscaling_read = var.autoscaling ? {
    scale_in_cooldown  = 50
    scale_out_cooldown = 40
    target_value       = 45
    max_capacity       = 10
  } : {}

  autoscaling_write = var.autoscaling ? {
    scale_in_cooldown  = 50
    scale_out_cooldown = 40
    target_value       = 45
    max_capacity       = 10
  } : {}

  tags = var.common_tags
}
