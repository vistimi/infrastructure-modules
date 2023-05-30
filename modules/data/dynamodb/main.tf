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

  billing_mode = var.predictable_workload ? "PROVISIONED" : "PAY_PER_REQUEST"

  read_capacity       = var.predictable_workload && var.predictable_capacity != null ? var.predictable_capacity.read.capacity : null
  write_capacity      = var.predictable_workload && var.predictable_capacity != null ? var.predictable_capacity.write.capacity : null
  autoscaling_enabled = var.predictable_workload && var.predictable_capacity != null ? var.predictable_capacity.autoscaling : false

  autoscaling_read = var.predictable_workload && var.predictable_capacity != null ? var.predictable_capacity.autoscaling ? {
    scale_in_cooldown  = var.predictable_capacity.read.scale_in_cooldown
    scale_out_cooldown = var.predictable_capacity.read.scale_out_cooldown
    target_value       = var.predictable_capacity.read.target_value
    max_capacity       = var.predictable_capacity.read.max_capacity
  } : {} : {}

  autoscaling_write = var.predictable_workload && var.predictable_capacity != null ? var.predictable_capacity.autoscaling ? {
    scale_in_cooldown  = var.predictable_capacity.write.scale_in_cooldown
    scale_out_cooldown = var.predictable_capacity.write.scale_out_cooldown
    target_value       = var.predictable_capacity.write.target_value
    max_capacity       = var.predictable_capacity.write.max_capacity
  } : {} : {}

  tags = var.common_tags
}

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

# {
#     "Version": "2012-10-17",
#     "Statement": [
#         {
#             "Sid": "ListAndDescribe",
#             "Effect": "Allow",
#             "Action": [
#                 "dynamodb:List*",
#                 "dynamodb:DescribeReservedCapacity*",
#                 "dynamodb:DescribeLimits",
#                 "dynamodb:DescribeTimeToLive"
#             ],
#             "Resource": "*"
#         },
#         {
#             "Sid": "SpecificTable",
#             "Effect": "Allow",
#             "Action": [
#                 "dynamodb:BatchGet*",
#                 "dynamodb:DescribeStream",
#                 "dynamodb:DescribeTable",
#                 "dynamodb:Get*",
#                 "dynamodb:Query",
#                 "dynamodb:Scan",
#                 "dynamodb:BatchWrite*",
#                 "dynamodb:CreateTable",
#                 "dynamodb:Delete*",
#                 "dynamodb:Update*",
#                 "dynamodb:PutItem"
#             ],
#             "Resource": "arn:aws:dynamodb:*:*:table/MyTable"
#         }
#     ]
# }
