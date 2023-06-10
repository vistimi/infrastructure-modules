data "aws_partition" "current" {}

locals {
  partition = data.aws_partition.current.partition // aws
}

module "microservice" {
  source = "../../components/microservice"

  common_name = var.common_name
  common_tags = var.common_tags
  vpc         = var.vpc

  ecs        = var.ecs
  ecr        = var.ecr
  bucket_env = var.bucket_env
}

#--------------
# Dynamodb
#--------------

# for_each = {
#     for index, dt in var.dynamodb_tables :
#     dt.name => dt # Perfect, since DT names also need to be unique
#   }

module "dynamodb_table" {
  source = "../../data/dynamodb"

  for_each = {
    for index, dt in var.dynamodb_tables :
    dt.name => dt # Perfect, since DT names also need to be unique
  }

  # TODO: handle no sort key
  table_name           = "${var.common_name}-${each.value.name}"
  primary_key_name     = each.value.primary_key_name
  primary_key_type     = each.value.primary_key_type
  sort_key_name        = each.value.sort_key_name
  sort_key_type        = each.value.sort_key_type
  predictable_workload = each.value.predictable_workload
  predictable_capacity = each.value.predictable_capacity

  common_tags = var.common_tags
}

// TODO: attach policy to containers
# resource "aws_iam_role" "dynamodb" {
#   name = "${var.table_name}-ec2"
#   tags = var.common_tags

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         "Sid" : "DescribeQueryScanBooksTable",
#         "Effect" : "Allow",
#         "Action" : [
#           "dynamodb:DescribeTable",
#           "dynamodb:BatchGet*",
#                 "dynamodb:DescribeStream",
#                 "dynamodb:Get*",
#                 "dynamodb:Query",
#                 "dynamodb:Scan",
#                 "dynamodb:BatchWrite*",
#                 "dynamodb:Delete*",
#                 "dynamodb:Update*",
#                 "dynamodb:PutItem"
#         ],
#         "Resource" : "arn:aws:dynamodb:us-west-2:account-id:table/Books"
#       }
#     ]
#   })
# }

#--------------
# Pictures
#--------------

module "bucket_picture" {
  source        = "../../data/bucket"
  name          = var.bucket_picture.name
  common_tags   = var.common_tags
  vpc_id        = var.vpc.id
  force_destroy = var.bucket_picture.force_destroy
  versioning    = var.bucket_picture.versioning
}

resource "aws_iam_policy" "bucket_picture" {
  name = "${var.common_name}-ecs-task-container-s3-picture"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["s3:GetBucketLocation", "s3:ListBucket"]
        Effect   = "Allow"
        Resource = "arn:${local.partition}:s3:::${var.bucket_picture.name}",
      },
      {
        Action   = ["s3:GetObject"]
        Effect   = "Allow"
        Resource = "arn:${local.partition}:s3:::${var.bucket_picture.name}/*",
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "bucket_picture" {
  role       = module.microservice.ecs.service.task_iam_role_name
  policy_arn = aws_iam_policy.bucket_picture.arn
}
