# Global
variable "region" {
  description = "The region on which the project is running, (e.g `us-east-1`)"
  type        = string
}

variable "service_name" {
  description = "The name of the project, (e.g `scraper-backend`)"
  type        = string
}

variable "environment_name" {
  description = "The name of the environment, (e.g `trunk`)"
  type        = string
}

variable "vpc_id" {
  description = "The IDs of the VPC which contains the subnets"
  type        = string
}

variable "subnets_ids" {
  description = "The IDs of the subnets for the ASG"
  type        = list(string)
}

# ---------------------------------------------------------------------------------------------------------------------
# MONGODB
# ---------------------------------------------------------------------------------------------------------------------

variable "db_version" {
  description = "The version of the database"
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# EC2
# ---------------------------------------------------------------------------------------------------------------------

variable "server_port" {
  description = "The port of the server to forward the traffic to"
  type        = number
}

variable "health_check_path" {
  description = "The path to forward the traffic to"
  type        = string
}

variable "elb_port" {
  description = "The port the ELB will use for HTTP requests"
  type        = number
  default     = 80
}

variable "ami_name" {
  description = "The name of the AMI used for the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "The type of EC2 Instances to run (e.g. t2.micro)"
  type        = string
}

variable "min_size" {
  description = "The minimum number of EC2 Instances in the ASG"
  type        = number
}

variable "max_size" {
  description = "The maximum number of EC2 Instances in the ASG"
  type        = number
}