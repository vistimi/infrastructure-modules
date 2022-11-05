# Global
variable "aws_region" {
  description = "The region on which the project is running, (e.g `us-east-1`)"
  type        = string
}

variable "common_tags" {
  description = "Custom tags to set on the Instances in the ASG"
  type        = map(string)
  default     = {}
}

variable "service_name" {
  description = "The name of the service"
  type        = string
  default     = {}
}

variable "vpc_id" {
  description = "The IDs of the VPC which contains the subnets"
  type        = string
}

variable "public_subnets_ids" {
  description = "The IDs of the public subnets for the ASG"
  type        = list(string)
}

# ECR
variable "repository_read_write_access_arns" {
  description = "the ARNs of the roles"
  type = list(string)
}

variable "repository_image_count" {
  description = "The amount of images to keep in the registry"
  type = number
}

# EC2
variable "ami_id"{
  description = "The ID of the AMI used for the EC2 instance"
  type        = string
  default = "ami-09d3b3274b6c5d4aa"
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

variable "desired_capacity" {
  description = "The maximum number of EC2 Instances in the ASG"
  type        = number
}