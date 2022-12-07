# Global
variable "account_region" {
  description = "The region on which the project is running, (e.g `us-east-1`)"
  type        = string
}

variable "account_id" {
  description = "The ID of the AWS account"
  type        = string
}

variable "account_name" {
  description = "The Name of the AWS account"
  type        = string
}

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

variable "force_destroy" {
  description = "If true, will delete the resources that still contain elements"
  type        = bool
}


# ------------
#     ECS
# ------------
variable "ecs_execution_role_name" {
  description = "The name of the role for ECS task execution"
  type        = string
}

variable "ecs_task_container_role_name" {
  description = "The name of the role for task container"
  type        = string
}

variable "ecs_task_definition_image_tag" {
  description = "The tag of the image in the ECR repository for deployment"
  type        = string
}

variable "ecs_task_container_s3_env_policy_name" {
  description = "The name of the policy to access the S3 env bucket"
  type        = string
}

# Cloudwatch
variable "ecs_logs_retention_in_days" {
  description = "The number of days to keep the logs in Cloudwatch"
  type        = number
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

# variable "bucket_env_name" {
#   description = "The name of the S3 bucket to store the env file"
#   type        = string
# }

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

# ------------
#     ECR
# ------------
# variable "repository_name" {
#   description = "The name of the repository"
#   type        = string
# }
# variable "repository_read_write_access_arns" {
#   description = "The ARNs of the IAM users/roles that have read/write access to the repository"
#   type = list(string)
#   default = []
# }

# variable "repository_read_access_arns" {
#   description = "The ARNs of the IAM users/roles that have read access to the repository"
#   type = list(string)
#   default = []
# }

variable "repository_image_keep_count" {
  description = "The amount of images to keep in the registry"
  type        = number
}

# ------------------------
#     Github
# ------------------------
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

variable "github_workflow_file_name_ecr" {
  description = "The name of the ECR workflow file"
  type        = string
}

variable "github_workflow_name_ecr" {
  description = "The name of the ECR workflow"
  type        = string
}

variable "github_workflow_file_name_env" {
  description = "The name of the S3 env workflow file"
  type        = string
}

variable "github_workflow_name_env" {
  description = "The name of the S3 env workflow"
  type        = string
}

variable "github_workflow_file_name_ecs" {
  description = "The name of the ECS workflow file"
  type        = string
}

variable "github_workflow_name_ecs" {
  description = "The name of the ECS workflow"
  type        = string
}

# ------------------------
#     Github
# ------------------------
variable "mongodb_ipv4" {
  description = "The IP of the Mongodb instance"
  type        = string
}