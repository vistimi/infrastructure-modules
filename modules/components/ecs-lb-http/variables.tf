# Global
variable "vpc_id" {
  description = "The IDs of the VPC which contains the subnets"
  type        = string
}

variable "vpc_security_group_ids" {
  description = "The IDs of the security group of the VPC"
  type        = list(string)
}

variable "common_name" {
  description = "The common part of the name used for all resources"
  type        = string
}

variable "common_tags" {
  description = "Custom tags to set on the Instances in the ASG"
  type        = map(string)
  default     = {}
}

# ALB
variable "listener_port" {
  description = "The port used by the containers, e.g. 8080"
  type        = number
}

variable "listener_protocol" {
  description = "The protocol used by the containers, e.g. http or https"
  type        = string
}

variable "target_port" {
  description = "The port used by the containers, e.g. 8080"
  type        = number
}

variable "target_protocol" {
  description = "The protocol used by the containers, e.g. http or https"
  type        = string
}

# ------------------------
#     Task definition
# ------------------------
variable "ecs_task_definition_memory" {
  description = "Amount (in MiB) of memory used by the task"
  type        = number
}

variable "ecs_task_definition_memory_reservation" {
  description = "Amount (in MiB) of memory reserved by the task"
  type        = number
}

variable "ecs_task_definition_cpu" {
  description = "Number of cpu units used by the task"
  type        = number
}

variable "ecs_task_desired_count" {
  description = "Number of instances of the task definition"
  type        = string
}

variable "bucket_env_name" {
  description = "The name of the S3 bucket to store the env file"
  type        = string
}

variable "env_file_name" {
  description = "The name of the env file used for the service docker"
  type        = string
}

variable "port_mapping" {
  description = "The mapping of the isntance ports towards the container ports"
  type = list(object({
    hostPort      = number
    protocol      = string
    containerPort = number
  }))
}

variable "ecs_task_definition_image_tag" {
  description = "The tag of the image in the ECR repository for deployment"
  type        = string
}

# ECS
variable "use_fargate" {
  description = "Use Fargate or EC2"
  type        = bool
}

variable "ecs_logs_retention_in_days" {
  description = "The number of days to keep the logs in Cloudwatch"
  type        = number
}

# variable "task_definition_arn" {
#   description = "Family and revision (family:revision) or full ARN of the task definition that you want to run in your service"
#   type        = string
# }

# ASG
variable "target_capacity_cpu" {
  description = "aws_ecs_capacity_provider"
  type        = number
}

variable "capacity_provider_base" {
  description = "It designates how many tasks, at a minimum, to run on the specified capacity provider. Only one capacity provider in a capacity provider strategy can have a base defined"
  type        = number
}

variable "capacity_provider_weight_on_demand" {
  description = "It designates the relative percentage of the total number of launched tasks that should use the specified capacity provider"
  type        = number
}

variable "capacity_provider_weight_spot" {
  description = "It designates the relative percentage of the total number of launched tasks that should use the specified capacity provider"
  type        = number
}

variable "user_data" {
  description = "The user data to provide when launching the instance. '#!/bin/bash\necho ECS_CLUSTER=my-cluster >> /etc/ecs/ecs.config' otherwise the instance will be launched in the default cluster"
  type        = string
  default     = null
}

variable "protect_from_scale_in" {
  description = "Allows setting instance protection. The autoscaling group will not select instances with this setting for termination during scale in events."
  type        = bool
  default     = false
}

variable "vpc_tier" {
  description = "The Tier of the vpc, e.g. `Public` or `Private`"
  type        = string
}

variable "instance_type_on_demand" {
  description = "The type of EC2 Instances to run (e.g. t2.micro). RAM GiB and vCPU"
  type        = string
}

variable "min_size_on_demand" {
  description = "The minimum number of EC2 Instances in the ASG"
  type        = number
}

variable "max_size_on_demand" {
  description = "The maximum number of EC2 Instances in the ASG"
  type        = number
}

variable "desired_capacity_on_demand" {
  description = "The maximum number of EC2 Instances in the ASG"
  type        = number
}

variable "maximum_scaling_step_size_on_demand" {
  description = "Maximum step adjustment size. A number between 1 and 10,000"
  type        = number
}

variable "minimum_scaling_step_size_on_demand" {
  description = "Minimum step adjustment size. A number between 1 and 10,000"
  type        = number
}

variable "ami_ssm_architecture_on_demand" {
  description = "The name of the ssm name to select the optimized AMI architecture"
  type        = string
  default     = "amazon-linux-2"
}

variable "instance_type_spot" {
  description = "The type of EC2 Instances to run (e.g. t2.micro)"
  type        = string
}

variable "min_size_spot" {
  description = "The minimum number of EC2 Instances in the ASG"
  type        = number
}

variable "max_size_spot" {
  description = "The maximum number of EC2 Instances in the ASG"
  type        = number
}

variable "desired_capacity_spot" {
  description = "The maximum number of EC2 Instances in the ASG"
  type        = number
}

variable "maximum_scaling_step_size_spot" {
  description = "Maximum step adjustment size. A number between 1 and 10,000"
  type        = number
}

variable "minimum_scaling_step_size_spot" {
  description = "Minimum step adjustment size. A number between 1 and 10,000"
  type        = number
}

variable "ami_ssm_architecture_spot" {
  description = "The name of the ssm name to select the optimized AMI architecture"
  type        = string
  default     = "amazon-linux-2"
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

# Github
variable "health_check_path" {
  description = "The path for the healthcheck"
  type        = string
  default     = "/"
}
