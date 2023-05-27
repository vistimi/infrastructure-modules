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
