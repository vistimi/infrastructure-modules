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

variable "log" {
  type = object({
    retention_days = number
    prefix         = optional(string)
  })
  default = {
    retention_days = 30
    prefix         = "ecs"
  }
}

variable "traffic" {
  type = object({
    listener_port     = number
    listener_protocol = string
    target_port       = number
    target_protocol   = string
    health_check_path = optional(string, "/")
  })
}

variable "deployment" {
  description = "if single instance, EC2 simple deployment. If multiple instances, you need to choose between EC2/Fargate with ECS"
  type = object({
    use_load_balancer = bool
    use_fargate       = optional(bool)
  })
}

variable "user_data" {
  description = "The user data to provide when launching the instance"
  type        = string
  default     = null
}

# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-types.html
variable "instance" {
  type = object({
    user_data = optional(string)
    ec2 = optional(object({
      ami_ssm_architecture = string
      instance_type        = string
    }))
    fargate = optional(object({
      os           = string
      architecture = string
    }))
  })
}

variable "capacity_provider" {
  description = "only one base for all capacity providers. The map key must be matching between capacity_providers/autoscaling"
  type = map(object({
    base           = optional(number)
    weight_percent = number
    fargate        = optional(string)
    scaling = optional(object({
      target_capacity_cpu_percent = number
      maximum_scaling_step_size   = number
      minimum_scaling_step_size   = number
    }))
  }))
}

variable "autoscaling_group" {
  description = "The map key must be matching between capacity_providers/autoscaling"
  type = map(object({
    min_size     = number
    desired_size = number
    max_size     = number
    use_spot     = bool
  }))
  default = {}
}

variable "task_definition" {
  type = object({
    memory             = number
    memory_reservation = optional(number)
    cpu                = number
    env_bucket_name    = string
    env_file_name      = string
    port_mapping = list(object({
      appProtocol        = optional(string)
      containerPort      = optional(number)
      containerPortRange = optional(string)
      hostPort           = optional(number)
      name               = optional(string)
      protocol           = optional(string)
    }))
    registry_image_tag = string
  })
}

variable "service_task_desired_count" {
  description = "Number of instances of the task definition"
  type        = string
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
