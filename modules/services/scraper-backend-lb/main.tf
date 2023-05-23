# ------------
#     Backend
# ------------
module "end" {
  source = "../../components/end-lb-http"

  vpc_id                 = var.vpc_id
  vpc_tier               = var.vpc_tier
  vpc_security_group_ids = var.vpc_security_group_ids
  common_name            = var.common_name
  common_tags            = var.common_tags

  use_fargate                            = var.use_fargate
  ecs_task_definition_image_tag          = var.ecs_task_definition_image_tag
  listener_port                          = var.listener_port
  listener_protocol                      = var.listener_protocol
  target_port                            = var.target_port
  target_protocol                        = var.target_protocol
  ecs_logs_retention_in_days             = var.ecs_logs_retention_in_days
  target_capacity_cpu                    = var.target_capacity_cpu
  capacity_provider_base                 = var.capacity_provider_base
  capacity_provider_weight_on_demand     = var.capacity_provider_weight_on_demand
  capacity_provider_weight_spot          = var.capacity_provider_weight_spot
  user_data                              = var.user_data
  protect_from_scale_in                  = var.protect_from_scale_in
  instance_type_on_demand                = var.instance_type_on_demand
  min_size_on_demand                     = var.min_size_on_demand
  max_size_on_demand                     = var.max_size_on_demand
  desired_capacity_on_demand             = var.desired_capacity_on_demand
  maximum_scaling_step_size_on_demand    = var.maximum_scaling_step_size_on_demand
  minimum_scaling_step_size_on_demand    = var.minimum_scaling_step_size_on_demand
  ami_ssm_architecture_on_demand         = var.ami_ssm_architecture_on_demand
  instance_type_spot                     = var.instance_type_spot
  min_size_spot                          = var.min_size_spot
  max_size_spot                          = var.max_size_spot
  desired_capacity_spot                  = var.desired_capacity_spot
  maximum_scaling_step_size_spot         = var.maximum_scaling_step_size_spot
  minimum_scaling_step_size_spot         = var.minimum_scaling_step_size_spot
  ami_ssm_architecture_spot              = var.ami_ssm_architecture_spot
  ecs_task_definition_memory             = var.ecs_task_definition_memory
  ecs_task_definition_memory_reservation = var.ecs_task_definition_memory_reservation
  ecs_task_definition_cpu                = var.ecs_task_definition_cpu
  ecs_task_desired_count                 = var.ecs_task_desired_count
  port_mapping                           = var.port_mapping
  repository_image_keep_count            = var.repository_image_keep_count
  force_destroy                          = var.force_destroy
  health_check_path                      = var.health_check_path
  bucket_env_name                        = var.bucket_env_name
  env_file_name                          = var.env_file_name
}

# ------------------------
#     Dynamodb tables
# ------------------------
module "dynamodb_table" {
  source = "../../data/dynamodb"

  for_each = {
    for index, dt in var.dynamodb_tables :
    dt.name => dt # Perfect, since DT names also need to be unique
  }

  # TODO: handle no sort key
  table_name       = "${var.common_name}-${each.value.name}"
  primary_key_name = each.value.primary_key_name
  primary_key_type = each.value.primary_key_type
  sort_key_name    = each.value.sort_key_name
  sort_key_type    = each.value.sort_key_type
  autoscaling      = var.dynamodb_autoscaling

  common_tags = var.common_tags
}

# ------------------------
#     Bucket picture
# ------------------------
module "bucket_picture" {
  source        = "../../data/bucket"
  bucket_name   = var.bucket_picture_name
  common_tags   = var.common_tags
  vpc_id        = var.vpc_id
  force_destroy = var.force_destroy
  versioning    = true
}
