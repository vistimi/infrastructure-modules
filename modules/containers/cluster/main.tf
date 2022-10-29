locals {
  name = "${var.project_name}-${var.environment_name}"
}


module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "~> 4.1.1"

  cluster_name = "${local.name}-ecs-ec2"

  cluster_configuration = {
    execute_command_configuration = {
      logging = "OVERRIDE"
      log_configuration = {
        cloud_watch_log_group_name = "/aws/ecs/aws-ec2"
      }
    }
  }

  autoscaling_capacity_providers = {
    # asg for regular instances
    one = {
      auto_scaling_group_arn         = var.auto_scaling_group_arn
      managed_termination_protection = "ENABLED"

      managed_scaling = {
        maximum_scaling_step_size = var.maximum_scaling_step_size
        minimum_scaling_step_size = var.minimum_scaling_step_size
        status                    = "ENABLED"
        target_capacity           = var.target_capacity
      }

      default_capacity_provider_strategy = {
        weight = 100
        base   = 20
      }
    }

    # TODO: add asg for spot instances
  }

  tags = common_tags
}
