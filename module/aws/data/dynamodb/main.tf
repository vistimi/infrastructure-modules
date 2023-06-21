data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  dns_suffix = data.aws_partition.current.dns_suffix // amazonaws.com
  partition  = data.aws_partition.current.partition  // aws
  region     = data.aws_region.current.name
}

module "dynamodb_table" {
  source  = "terraform-aws-modules/dynamodb-table/aws"
  version = "3.3.0"

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

  tags = var.tags
}

#-------------------
#   Attachments
#-------------------
resource "aws_iam_policy" "role_attachment" {
  name = "${var.table_name}-role-attachment"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:BatchGet*",
          "dynamodb:DescribeStream",
          "dynamodb:DescribeTable",
          "dynamodb:Get*",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchWrite*",
          "dynamodb:Delete*",
          "dynamodb:Update*",
          "dynamodb:PutItem",
        ]
        Effect   = "Allow"
        Resource = "arn:${local.partition}:dynamodb:${local.region}:${local.account_id}:table/${var.table_name}",
      },
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "role_attachment" {
  count = length(var.role_names)

  role       = var.role_names[count.index]
  policy_arn = aws_iam_policy.role_attachment.arn
}
