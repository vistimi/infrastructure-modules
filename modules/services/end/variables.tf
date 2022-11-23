# Global
variable "vpc_id" {
  description = "The IDs of the VPC which contains the subnets"
  type        = string
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

# Github
variable "gh_organization" {
  description = "The name of the Github organization that contains the repo"
  type        = string
}

variable "gh_repository" {
   description = "The name of the repository"
  type        = string
}


# Task definition
# variable "task_definition_json_path" {
#   description = "The path to the JSON config file"
#   type        = string
# }

# # ECR
# variable "repository_read_write_access_arns" {
#   description = "The ARNs of the IAM users/roles that have read/write access to the repository"
#   type = list(string)
#   default = []
# }

# variable "repository_read_access_arns" {
#   description = "The ARNs of the IAM users/roles that have read/write access to the repository"
#   type = list(string)
#   default = []
# }

# variable "repository_image_count" {
#   description = "The amount of images to keep in the registry"
#   type = number
# }

# variable "repository_force_delete" {
#   description = "If true, will delete the repository even if it contains images. Defaults to false"
#   type = bool
# }


# ALB
variable "listener_port" {
  description = "The port used by the containers, e.g. 8080"
  type        = number
}

variable "listener_protocol" {
  description = "The protocol used by the containers, e.g. http or https"
  type        = number
}

variable "target_port" {
  description = "The port used by the containers, e.g. 8080"
  type        = number
}

variable "target_protocol" {
  description = "The protocol used by the containers, e.g. http or https"
  type        = number
}

# ECS

# variable "task_definition_arn" {
#    description = "The task definition ARN generated from the version controller"
#   type        = string
# }

variable "ecs_logs_retention_in_days" {
  description = "The number of days to keep the logs in Cloudwatch"
  type        = number
}

variable "ecs_execution_role_name" {
  description = "The name of the role for ECS task execution"
  type        = string
}

variable "ecs_task_container_role_name" {
  description = "The name of the role for task container"
  type        = string
}

# ASG
variable "user_data" {
  description = "The user data to provide when launching the instance"
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
  description = "The type of EC2 Instances to run (e.g. t2.micro)"
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
