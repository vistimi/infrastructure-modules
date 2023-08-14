# https://registry.terraform.io/module/terraform-aws-modules/elb/aws/8.6.0?utm_content=documentLink&utm_medium=Visual+Studio+Code&utm_source=terraform-ls#outputs
output "elb" {
  value = {
    http_tcp_listener_arns    = module.elb.http_tcp_listener_arns
    http_tcp_listener_ids     = module.elb.http_tcp_listener_ids
    https_listener_arns       = module.elb.https_listener_arns
    https_listener_ids        = module.elb.https_listener_ids
    lb_arn                    = module.elb.lb_arn
    lb_arn_suffix             = module.elb.lb_arn_suffix
    lb_dns_name               = module.elb.lb_dns_name
    lb_id                     = module.elb.lb_id
    lb_zone_id                = module.elb.lb_zone_id
    security_group_arn        = module.elb.security_group_arn
    security_group_id         = module.elb.security_group_id
    target_group_arn_suffixes = module.elb.target_group_arn_suffixes
    target_group_arns         = module.elb.target_group_arns
    target_group_attachments  = module.elb.target_group_attachments
    target_group_names        = module.elb.target_group_names
  }
}

output "acm" {
  value = {
    for key, acm in module.acm : key => {
      acm_certificate_arn                       = acm.acm_certificate_arn
      acm_certificate_domain_validation_options = acm.acm_certificate_domain_validation_options
      acm_certificate_status                    = acm.acm_certificate_status
      acm_certificate_validation_emails         = acm.acm_certificate_validation_emails
      distinct_domain_names                     = acm.distinct_domain_names
      validation_domains                        = acm.validation_domains
      validation_route53_record_fqdns           = acm.validation_route53_record_fqdns
    }
  }
}

output "route53" {
  value = {
    records = {
      for key, record in module.route53_records : key => {
        name = record.name
        fqdn = record.fqdn
      }
    }
  }
}

# https://registry.terraform.io/module/terraform-aws-modules/autoscaling/aws/6.10.0?utm_content=documentLink&utm_medium=Visual+Studio+Code&utm_source=terraform-ls#outputs
output "asg" {
  value = {
    for key, asg in module.asg : key => {
      autoscaling_group_arn                       = asg.autoscaling_group_arn
      autoscaling_group_availability_zones        = asg.autoscaling_group_availability_zones
      autoscaling_group_default_cooldown          = asg.autoscaling_group_default_cooldown
      autoscaling_group_desired_capacity          = asg.autoscaling_group_desired_capacity
      autoscaling_group_enabled_metrics           = asg.autoscaling_group_enabled_metrics
      autoscaling_group_health_check_grace_period = asg.autoscaling_group_health_check_grace_period
      autoscaling_group_health_check_type         = asg.autoscaling_group_health_check_type
      autoscaling_group_id                        = asg.autoscaling_group_id
      autoscaling_group_load_balancers            = asg.autoscaling_group_load_balancers
      autoscaling_group_max_size                  = asg.autoscaling_group_max_size
      autoscaling_group_min_size                  = asg.autoscaling_group_min_size
      autoscaling_group_name                      = asg.autoscaling_group_name
      autoscaling_group_target_group_arns         = asg.autoscaling_group_target_group_arns
      autoscaling_group_vpc_zone_identifier       = asg.autoscaling_group_vpc_zone_identifier
      autoscaling_policy_arns                     = asg.autoscaling_policy_arns
      autoscaling_schedule_arns                   = asg.autoscaling_schedule_arns
      iam_instance_profile_arn                    = asg.iam_instance_profile_arn
      iam_instance_profile_id                     = asg.iam_instance_profile_id
      iam_instance_profile_unique                 = asg.iam_instance_profile_unique
      iam_role_arn                                = asg.iam_role_arn
      iam_role_name                               = asg.iam_role_name
      iam_role_unique_id                          = asg.iam_role_unique_id
      launch_template_arn                         = asg.launch_template_arn
      launch_template_default_version             = asg.launch_template_default_version
      launch_template_id                          = asg.launch_template_id
      launch_template_latest_version              = asg.launch_template_latest_version
      launch_template_name                        = asg.launch_template_name
    }
  }
}

# https://github.com/terraform-aws-modules/terraform-aws-ecs/blob/master/outputs.tf
output "cluster" {
  value = {
    arn                            = module.ecs.cluster_arn
    id                             = module.ecs.cluster_id
    name                           = module.ecs.cluster_name
    cloudwatch_log_group_name      = module.ecs.cloudwatch_log_group_name
    cloudwatch_log_group_arn       = module.ecs.cloudwatch_log_group_arn
    cluster_capacity_providers     = module.ecs.cluster_capacity_providers
    autoscaling_capacity_providers = module.ecs.autoscaling_capacity_providers
    task_exec_iam_role_name        = module.ecs.task_exec_iam_role_name
    task_exec_iam_role_arn         = module.ecs.task_exec_iam_role_arn
    task_exec_iam_role_unique_id   = module.ecs.task_exec_iam_role_unique_id
  }
}

# https://github.com/terraform-aws-modules/terraform-aws-ecs/blob/master/module/service/outputs.tf
output "service" {
  value = {
    # service
    id   = module.ecs.services["unique"].id
    name = module.ecs.services["unique"].name
    # service iam role
    iam_role_arn       = module.ecs.services["unique"].iam_role_arn
    iam_role_name      = module.ecs.services["unique"].iam_role_name
    iam_role_unique_id = module.ecs.services["unique"].iam_role_unique_id
    # container
    container_definitions = module.ecs.services["unique"].container_definitions
    # task definition
    task_definition_arn      = module.ecs.services["unique"].task_definition_arn
    task_definition_revision = module.ecs.services["unique"].task_definition_revision
    task_definition_family   = module.ecs.services["unique"].task_definition_family
    # task execution iam role
    task_exec_iam_role_name      = module.ecs.services["unique"].task_exec_iam_role_name
    task_exec_iam_role_arn       = module.ecs.services["unique"].task_exec_iam_role_arn
    task_exec_iam_role_unique_id = module.ecs.services["unique"].task_exec_iam_role_unique_id
    # task iam role
    task_iam_role_arn       = module.ecs.services["unique"].tasks_iam_role_arn
    task_iam_role_name      = module.ecs.services["unique"].tasks_iam_role_name
    task_iam_role_unique_id = module.ecs.services["unique"].tasks_iam_role_unique_id
    # task set
    task_set_id               = module.ecs.services["unique"].task_set_id
    task_set_arn              = module.ecs.services["unique"].task_set_arn
    task_set_stability_status = module.ecs.services["unique"].task_set_stability_status
    task_set_status           = module.ecs.services["unique"].task_set_status
    # autoscaling
    autoscaling_policies          = module.ecs.services["unique"].autoscaling_policies
    autoscaling_scheduled_actions = module.ecs.services["unique"].autoscaling_scheduled_actions
    # security group
    security_group_arn = module.ecs.services["unique"].security_group_arn
    security_group_id  = module.ecs.services["unique"].security_group_id
  }
}
