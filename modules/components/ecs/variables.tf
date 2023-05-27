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

# ------------------------
#     Task definition
# ------------------------
variable "task_definition" {
  type = object({
    memory             = number
    memory_reservation = optional(number)
    cpu                = number
    env_bucket_name    = string
    env_file_name      = string
    port_mapping = list(object({
      hostPort      = number
      protocol      = string
      containerPort = number
    }))
    registry_image_tag = string
  })
}

variable "service_task_desired_count" {
  description = "Number of instances of the task definition"
  type        = string
}

variable "use_fargate" {
  description = "Use Fargate or EC2"
  type        = bool
}

variable "user_data" {
  description = "The user data to provide when launching the instance"
  type        = string
  default     = null
}

variable "instance" {
  type = object({
    user_data = optional(string)
    ec2 = optional(object({
      ami_ssm_architecture = string
      instance_type        = string
      }), {
      ami_ssm_architecture = "amazon-linux-2"
      instance_type        = "t2.micro"
    })
    fargate = optional(object({
      os           = string
      architecture = string
      }), {
      os           = "LINUX"
      architecture = "X86_64"
    })
  })
}

variable "capacity_provider" {
  description = "only one base for all capacity providers to define which are the necessary instances. The map key must be matching between capacity_providers/autoscaling. Either use fargate or ec2 based on the deployment configuration. "
  type = map(object({
    base           = optional(number)
    weight_percent = number
    fargate        = optional(string, "FARGATE")
    scaling = optional(object({
      target_capacity_cpu_percent = number
      maximum_scaling_step_size   = number
      minimum_scaling_step_size   = number
      }), {
      target_capacity_cpu_percent = 70
      maximum_scaling_step_size   = 1
      minimum_scaling_step_size   = 1
    })
  }))
}

variable "autoscaling_group" {
  description = "Only necessary for EC2 deployment. The map key must be matching between capacity_providers/autoscaling"
  type = map(object({
    min_size     = number
    desired_size = number
    max_size     = number
    use_spot     = bool
  }))

  default = {
    spot = {
      min_size     = 0
      desired_size = 1
      max_size     = 2
      use_spot     = true
    },
    on-demand = {
      min_size     = 0
      desired_size = 1
      max_size     = 2
      use_spot     = false
    }
  }
}

variable "ami_ssm_name" {
  description = "Map to select an optimized ami for the correct architecture"
  type        = map(string)

  default = {
    amazon-linux-2       = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended"
    amazon-linux-2-arm64 = "/aws/service/ecs/optimized-ami/amazon-linux-2/arm64/recommended"
    amazon-linux-2-gpu   = "/aws/service/ecs/optimized-ami/amazon-linux-2/gpu/recommended"
  }
}
