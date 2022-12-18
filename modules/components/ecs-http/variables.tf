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

variable "account_region" {
  description = "The region on which the project is running, (e.g `us-east-1`)"
  type        = string
}

variable "account_name" {
  description = "The Name of the AWS account"
  type        = string
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

# ECS
variable "ecs_logs_retention_in_days" {
  description = "The number of days to keep the logs in Cloudwatch"
  type        = number
}

variable "task_definition_arn" {
  description = "Family and revision (family:revision) or full ARN of the task definition that you want to run in your service"
  type        = string
}

variable "ecs_task_desired_count" {
  description = "Number of instances of the task definition"
  type        = string
}

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

# Github
variable "github_organization" {
  description = "The name of the Github organization that contains the repo"
  type        = string
}

variable "github_repository" {
  description = "The name of the repository"
  type        = string
}

variable "github_branch" {
  description = "The name of the branch"
  type        = string
}

variable "health_check_path" {
  description = "The path for the healthcheck"
  type        = string
  default     = "/"
}