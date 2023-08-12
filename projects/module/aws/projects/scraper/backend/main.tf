locals {
  config_vars = yamldecode(file("./config.yml"))
  name        = lower(join("-", [local.config_vars.name, var.name_suffix]))
}

module "microservice" {
  source = "../../../../../module/aws/container/microservice"

  name       = local.name
  vpc        = var.vpc
  route53    = var.microservice.route53
  ecs        = var.microservice.ecs
  bucket_env = var.microservice.bucket_env
  iam        = var.microservice.iam

  tags = var.tags
}

module "dynamodb_table" {
  source = "../../../../../module/aws/data/dynamodb"

  for_each = {
    for index, dt in var.dynamodb_tables :
    dt.name => dt
  }

  # TODO: handle no sort key
  table_name                   = "${local.name}-${each.value.name}"
  primary_key_name             = each.value.primary_key_name
  primary_key_type             = each.value.primary_key_type
  sort_key_name                = each.value.sort_key_name
  sort_key_type                = each.value.sort_key_type
  predictable_workload         = each.value.predictable_workload
  predictable_capacity         = each.value.predictable_capacity
  table_attachement_role_names = [module.microservice.ecs.service.task_iam_role_name]
  iam                          = var.microservice.iam

  tags = var.tags
}

module "bucket_picture" {
  source = "../../../../../module/aws/data/bucket"

  name                          = "${local.name}-${var.bucket_picture.name}"
  force_destroy                 = var.bucket_picture.force_destroy
  versioning                    = var.bucket_picture.versioning
  bucket_attachement_role_names = [module.microservice.ecs.service.task_iam_role_name]
  iam                           = var.microservice.iam

  tags = var.tags
}
