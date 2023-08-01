variable "name" {
  description = "The common part of the name used for all resources"
  type        = string
}

variable "tags" {
  description = "Custom tags to set on the Instances in the ASG"
  type        = map(string)
  default     = {}
}

variable "microservice" {
  type = object({
    vpc = object({
      name       = string
      cidr_ipv4  = string
      tier       = string
      enable_nat = optional(bool)
    })
    route53 = optional(object({
      zones = list(object({
        name = string
      }))
      record = object({
        subdomain_name = string
        prefixes       = optional(list(string))
      })
    }))
    bucket_env = object({
      name          = string
      force_destroy = bool
      versioning    = bool
      file_path     = string
      file_key      = string
    })
    iam = object({
      scope       = string
      account_ids = optional(list(string))
      vpc_ids     = optional(list(string))
    })
    ecs = object({
      service = object({
        deployment_type                    = string
        task_min_count                     = number
        task_desired_count                 = number
        task_max_count                     = number
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
      traffics = list(object({
        listener = object({
          protocol         = string
          port             = optional(number)
          protocol_version = optional(string)
        })
        target = object({
          protocol          = string
          port              = number
          protocol_version  = optional(string)
          health_check_path = optional(string)
        })
      }))
      task_definition = object({
        memory             = number
        memory_reservation = optional(number)
        cpu                = number
        env_bucket_name    = string
        env_file_name      = string
        docker = object({
          registry = object({
            name = optional(string)
            ecr = optional(object({
              privacy      = string
              public_alias = optional(string)
              account_id   = optional(string)
              region_name  = optional(string)
            }))
          })
          repository = object({
            name = string
          })
          image = optional(object({
            tag = string
          }))
        })
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
        os           = string
        architecture = string
        capacity_provider = map(object({
          key    = string
          base   = optional(number)
          weight = optional(number)
        }))
      }))
      ec2 = optional(map(object({
        user_data     = optional(string)
        instance_type = string
        os            = string
        os_version    = string
        architecture  = string
        use_spot      = bool
        key_name      = optional(string)
        asg = object({
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
          base                        = optional(number)
          weight                      = number
          target_capacity_cpu_percent = number
          maximum_scaling_step_size   = optional(number)
          minimum_scaling_step_size   = optional(number)
        })
      })))
    })
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
