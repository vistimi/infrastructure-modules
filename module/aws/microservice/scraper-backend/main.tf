module "microservice" {
  source = "../../../../module/aws/container/microservice"

  common_name = var.common_name
  common_tags = var.common_tags
  vpc         = var.microservice.vpc

  ecs        = var.microservice.ecs
  bucket_env = var.microservice.bucket_env
}

module "dynamodb_table" {
  source = "../../../../module/aws/data/dynamodb"

  for_each = {
    for index, dt in var.dynamodb_tables :
    dt.name => dt
  }

  # TODO: handle no sort key
  table_name           = "${var.common_name}-${each.value.name}"
  primary_key_name     = each.value.primary_key_name
  primary_key_type     = each.value.primary_key_type
  sort_key_name        = each.value.sort_key_name
  sort_key_type        = each.value.sort_key_type
  predictable_workload = each.value.predictable_workload
  predictable_capacity = each.value.predictable_capacity
  role_names           = [module.microservice.ecs.service.task_iam_role_name]

  tags = var.common_tags
}

module "bucket_picture" {
  source        = "../../../../module/aws/data/bucket"
  name          = var.bucket_picture.name
  vpc_id        = module.microservice.vpc.vpc_id
  force_destroy = var.bucket_picture.force_destroy
  versioning    = var.bucket_picture.versioning
  role_names    = [module.microservice.ecs.service.task_iam_role_name]

  tags = var.common_tags
}
