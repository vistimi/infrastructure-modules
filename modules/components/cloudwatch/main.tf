# add SNS topic to choose how to send notifications
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic#example-with-delivery-policy

# https://github.com/terraform-aws-modules/terraform-aws-cloudwatch/blob/master/examples/complete-log-metric-filter-and-alarm/main.tf
module "log_group" {
  source = "../../modules/log-group"

  name_prefix = "my-app-"
}

locals {
  metric_transformation_name      = "ErrorCount"
  metric_transformation_namespace = "MyAppNamespace"
}

module "log_metric_filter" {
  source = "../../modules/log-metric-filter"

  log_group_name = module.log_group.cloudwatch_log_group_name

  name    = "metric-${module.log_group.cloudwatch_log_group_name}"
  pattern = "ERROR"

  metric_transformation_namespace = local.metric_transformation_namespace
  metric_transformation_name      = local.metric_transformation_name
}

module "alarm" {
  source = "../../modules/metric-alarm"

  alarm_name          = "log-errors-${module.log_group.cloudwatch_log_group_name}"
  alarm_description   = "Log errors are too high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  threshold           = 10
  period              = 60
  unit                = "Count"

  namespace   = local.metric_transformation_namespace
  metric_name = local.metric_transformation_name
  statistic   = "Sum"

  alarm_actions = [var.sns_topic_arn]
}