variable "common_name" {
  description = "The common part of the name used for all resources"
  type        = string
}

variable "common_tags" {
  description = "Custom tags to set on the Instances in the ASG"
  type        = map(string)
  default     = {}
}

variable "vpc" {
  type = object({
    id                 = string
    security_group_ids = list(string)
    tier               = string
  })
}

variable "ecs" {
  type = object({
    service = object({
      use_fargate                        = bool
      task_desired_count                 = number
      deployment_maximum_percent         = optional(number)
      deployment_minimum_healthy_percent = optional(number)
      deployment_circuit_breaker = optional(object({
        enable   = bool
        rollback = bool
      }))
    })
    log = object({
      retention_days = number
      prefix         = optional(string)
    })
    traffic = object({
      listener_port             = number
      listener_protocol         = string
      listener_protocol_version = string
      target_port               = number
      target_protocol           = string
      target_protocol_version   = string
      health_check_path         = optional(string)
    })
    capacity_provider = map(object({
      base           = optional(number)
      weight_percent = number
    }))
    task_definition = object({
      memory               = number
      memory_reservation   = optional(number)
      cpu                  = number
      env_bucket_name      = string
      env_file_name        = string
      repository_name      = string
      repository_image_tag = string
      tmpfs = optional(object({
        ContainerPath : optional(string),
        MountOptions : optional(list(string)),
        Size : number,
      }))
      environment = optional(list(object({
        name : string
        value : string
      })))
    })
    fargate = optional(object({
      os                = string
      architecture      = string
      capacity_provider = map(string)
    }))
    ec2 = optional(map(object({
      user_data            = optional(string)
      instance_type        = string
      ami_ssm_architecture = string
      use_spot             = bool
      key_name             = optional(string)
      asg = object({
        min_size     = number
        desired_size = number
        max_size     = number
        instance_refresh = optional(object({
          strategy = string
          preferences = optional(object({
            checkpoint_delay       = optional(number)
            checkpoint_percentages = optional(list(number))
            instance_warmup        = optional(number)
            min_healthy_percentage = optional(number)
            skip_matching          = optional(bool)
            auto_rollback          = optional(bool)
          }))
          triggers = optional(list(string))
        }))
      })
      capacity_provider = object({
        target_capacity_cpu_percent = number
        maximum_scaling_step_size   = number
        minimum_scaling_step_size   = number
      })
    })), {})
  })
}

variable "bucket_env" {
  type = object({
    name          = string
    force_destroy = bool
    versioning    = bool
    file_path     = string
    file_key      = string
  })
}

#--------------
# Dynamodb
#--------------

variable "dynamodb_tables" {
  description = "The mapping of the DynamoDB tables"
  type = list(object({
    name                 = string
    primary_key_name     = string
    primary_key_type     = string
    sort_key_name        = string
    sort_key_type        = string
    predictable_workload = bool
    predictable_capacity = optional(object({
      autoscaling = bool
      read = optional(object({
        capacity           = number
        scale_in_cooldown  = number
        scale_out_cooldown = number
        target_value       = number
        max_capacity       = number
      }))
      write = optional(object({
        capacity           = number
        scale_in_cooldown  = number
        scale_out_cooldown = number
        target_value       = number
        max_capacity       = number
      }))
    }))
  }))
}

#--------------
# Pictures
#--------------

variable "bucket_picture" {
  type = object({
    name          = string
    force_destroy = bool
    versioning    = bool
  })
}
