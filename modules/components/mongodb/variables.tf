variable "cluster_name" {
  description = "The cluster name for the resources for mongodb"
  type        = string
}

variable "common_tags" {
  description = "Custom tags to set on the Instances in the ASG"
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "The IDs of the VPC which contains the subnets"
  type        = string
}

variable "subnets_id" {
  description = "The ID of the subnet for the EC2 instance"
  type        = string
}

variable "bucket_name" {
  description = "The name of backup used to store and lock the states"
  type        = string
}

variable "db_version" {
  description = "The version of the database"
  type        = string
}

variable "ami_name" {
  description = "The name of the AMI used for the EC2 instance"
  type        = string
}