# Global

variable "zone" {
  description = "The region on which the project is running, (e.g `us-east-1`)"
  type        = string
}

variable "vpc_name" {
  description = "The name of the vpc, (e.g `vpc-scraper`)"
  type        = string
}

variable "service_name" {
  description = "The name of the service, (e.g `scraper-backend`)"
  type        = string
}

variable "environment_name" {
  description = "The name of the environment, (e.g `trunk`)"
  type        = string
}

# Mongodb

variable "db_version" {
  description = "The version of the database"
  type        = string
}

# EC2

variable "instance_type" {
  description = "The type of EC2 Instances to run (e.g. `t2.micro`)"
  type        = string
}

variable "max_size" {
  description = "The maximum number of EC2 Instances in the ASG"
  type        = number
}