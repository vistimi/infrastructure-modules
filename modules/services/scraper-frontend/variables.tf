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
  description = "The tag of the image in the repository"
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
  default = "amazon-linux-2"
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
  default = "amazon-linux-2"
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

# ------------
#     ECR
# ------------
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

variable "github_repository_id" {
  description = "The ID of the repository"
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