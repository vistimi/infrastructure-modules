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
      health_check_path         = optional(string, "/")
    })
    capacity_provider = map(object({
      base           = optional(number)
      weight_percent = number
    }))
    task_definition = object({
      memory             = number
      memory_reservation = optional(number)
      cpu                = number
      env_bucket_name    = string
      env_file_name      = string
      registry_image_tag = string
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
  })
}

variable "ecr" {
  description = "The registry config"
  type = object({
    image_keep_count = number
    force_destroy    = bool
  })

  default = {
    image_keep_count = 1
    force_destroy    = true
  }
}
