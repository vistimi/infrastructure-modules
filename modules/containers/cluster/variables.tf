# Global
variable "aws_region" {
  description = "The aws_region on which the project is running, (e.g `us-east-1`)"
  type        = string
}

variable "project_name" {
  description = "The name of the project, (e.g `scraper`)"
  type        = string
}

variable "environment_name" {
  description = "The name of the environment, (e.g `trunk`)"
  type        = string
}

variable "common_tags" {
  description = "Custom tags to set on the Instances in the ASG"
  type        = map(string)
  default     = {}
}

# ASG
variable "auto_scaling_group_arn"{
  description = "The ARN of the ASG"
  type = string
}

variable "maximum_scaling_step_size"{
  description = "The ARN of the ASG"
  type = number
  default = 5
}

variable "minimum_scaling_step_size"{
  description = "The ARN of the ASG"
  type = number
   default = 1
}

variable "target_capacity"{
  description = "The CPU capacity utilization "
  type = number
  default = 60
}