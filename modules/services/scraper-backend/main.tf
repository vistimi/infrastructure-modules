module "microservice" {
  source = "../../components/microservice"

  common_name = var.common_name
  common_tags = var.common_tags
  vpc         = var.vpc

  deployment                 = var.deployment
  user_data                  = var.user_data
  instance                   = var.instance
  service_task_desired_count = var.service_task_desired_count
  traffic                    = var.traffic
  log                        = var.log

  capacity_provider = var.capacity_provider
  autoscaling_group = var.autoscaling_group

  task_definition = var.task_definition
  ecr             = var.ecr
  bucket_env      = var.bucket_env
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
#           "dynamodb:Query",
#           "dynamodb:Scan"
#         ],
#         "Resource" : "arn:aws:dynamodb:us-west-2:account-id:table/Books"
#       }
#     ]
#   })
# }

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

module "bucket_picture" {
  source        = "../../data/bucket"
  bucket_name   = var.bucket_picture.name
  common_tags   = var.common_tags
  vpc_id        = var.vpc.id
  force_destroy = var.bucket_picture.force_destroy
  versioning    = var.bucket_picture.versioning
}
