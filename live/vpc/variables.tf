variable "region" {
  description = "The region on which the project is running, (e.g `us-east-1`)"
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

variable "backup_name" {
  description = "The name of backup used to store and lock the states"
  type        = string
}

variable "vpc_cidr_ipv4" {
  description = "The prefix of the vpc CIDR block (e.g. 160.0.0.0/16)"
  type        = string
}