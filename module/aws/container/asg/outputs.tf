# https://registry.terraform.io/module/terraform-aws-modules/autoscaling/aws/6.10.0?utm_content=documentLink&utm_medium=Visual+Studio+Code&utm_source=terraform-ls#outputs
output "asg" {
  value = {
    autoscaling_group_arn                       = module.asg.autoscaling_group_arn
    autoscaling_group_availability_zones        = module.asg.autoscaling_group_availability_zones
    autoscaling_group_default_cooldown          = module.asg.autoscaling_group_default_cooldown
    autoscaling_group_desired_capacity          = module.asg.autoscaling_group_desired_capacity
    autoscaling_group_enabled_metrics           = module.asg.autoscaling_group_enabled_metrics
    autoscaling_group_health_check_grace_period = module.asg.autoscaling_group_health_check_grace_period
    autoscaling_group_health_check_type         = module.asg.autoscaling_group_health_check_type
    autoscaling_group_id                        = module.asg.autoscaling_group_id
    autoscaling_group_load_balancers            = module.asg.autoscaling_group_load_balancers
    autoscaling_group_max_size                  = module.asg.autoscaling_group_max_size
    autoscaling_group_min_size                  = module.asg.autoscaling_group_min_size
    autoscaling_group_name                      = module.asg.autoscaling_group_name
    autoscaling_group_target_group_arns         = module.asg.autoscaling_group_target_group_arns
    autoscaling_group_vpc_zone_identifier       = module.asg.autoscaling_group_vpc_zone_identifier
    autoscaling_policy_arns                     = module.asg.autoscaling_policy_arns
    autoscaling_schedule_arns                   = module.asg.autoscaling_schedule_arns
    iam_instance_profile_arn                    = module.asg.iam_instance_profile_arn
    iam_instance_profile_id                     = module.asg.iam_instance_profile_id
    iam_instance_profile_unique                 = module.asg.iam_instance_profile_unique
    iam_role_arn                                = module.asg.iam_role_arn
    iam_role_name                               = module.asg.iam_role_name
    iam_role_unique_id                          = module.asg.iam_role_unique_id
    launch_template_arn                         = module.asg.launch_template_arn
    launch_template_default_version             = module.asg.launch_template_default_version
    launch_template_id                          = module.asg.launch_template_id
    launch_template_latest_version              = module.asg.launch_template_latest_version
    launch_template_name                        = module.asg.launch_template_name
  }
}
