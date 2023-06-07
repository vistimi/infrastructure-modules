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

variable "deployment" {
  description = "if single instance, EC2 simple deployment. If multiple instances, you need to choose between EC2/Fargate with ECS"
  type = object({
    use_load_balancer = bool
    use_fargate       = optional(bool)
  })
  default = {
    use_load_balancer = true
    use_fargate       = true
  }
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
    amazon-linux-2          = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended"
    amazon-linux-2-arm64    = "/aws/service/ecs/optimized-ami/amazon-linux-2/arm64/recommended"
    amazon-linux-2-gpu      = "/aws/service/ecs/optimized-ami/amazon-linux-2/gpu/recommended"
    amazon-linux-2-inf      = "/aws/service/ecs/optimized-ami/amazon-linux-2/inf/recommended"
    amazon-linux-2023       = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended"
    amazon-linux-2023-arm64 = "/aws/service/ecs/optimized-ami/amazon-linux-2023/arm64/recommended"
    # amazon-linux-2023-gpu   = "/aws/service/ecs/optimized-ami/amazon-linux-2023/gpu/recommended"
    amazon-linux-2023-inf = "/aws/service/ecs/optimized-ami/amazon-linux-2023/inf/recommended"
  }
}

# ebs_device_map = {
#   amazon2       = "/dev/sdf"
#   amazon2023    = "/dev/sdf"
#   amazoneks     = "/dev/sdf"
#   amazonecs     = "/dev/xvdcz"
#   rhel7         = "/dev/sdf"
#   rhel8         = "/dev/sdf"
#   centos7       = "/dev/sdf"
#   ubuntu18      = "/dev/sdf"
#   ubuntu20      = "/dev/sdf"
#   debian10      = "/dev/sdf"
#   debian11      = "/dev/sdf"
#   windows2012r2 = "xvdf"
#   windows2016   = "xvdf"
#   windows2019   = "xvdf"
#   windows2022   = "xvdf"
# }

# root_device_map = {
#   amazon2       = "/dev/xvda"
#   amazon2023    = "/dev/xvda"
#   amazoneks     = "/dev/xvda"
#   amazonecs     = "/dev/xvda"
#   rhel7         = "/dev/sda1"
#   rhel8         = "/dev/sda1"
#   centos7       = "/dev/sda1"
#   ubuntu18      = "/dev/sda1"
#   ubuntu20      = "/dev/sda1"
#   windows2012r2 = "/dev/sda1"
#   windows2016   = "/dev/sda1"
#   windows2019   = "/dev/sda1"
#   windows2022   = "/dev/sda1"
#   debian10      = "/dev/sda1"
#   debian11      = "/dev/sda1"
# }
