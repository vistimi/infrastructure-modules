# Global
variable "region" {
  description = "The region on which the project is running, (e.g `us-east-1`)"
  type        = string
}

variable "vpc_name" {
  description = "The name of the vpc, (e.g `vpc-scraper`)"
  type        = string
}

variable "cluster_name" {
  description = "The name of the EC2 cluster"
  type        = string
}

variable "common_tags" {
  description = "Custom tags to set on the Instances in the ASG"
  type        = map(string)
  default     = {}
}

variable "backup_name" {
  description = "The name of backup used to store and lock the states"
  type        = string
}

# Specific
variable "server_port" {
  description = "The port of the server to forward the traffic to"
  type        = number
}

variable "health_check_path" {
  description = "The path to forward the traffic to"
  type        = string
}

# EC2
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