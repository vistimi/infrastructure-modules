# Global
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

variable "vpc_cidr_ipv4" {
  description = "The prefix of the vpc CIDR block (e.g. 160.0.0.0/16)"
  type        = string
}

# User Data
variable "user_data_path" {
  description = "Bash script path to run after creation of instance"
  type        = string
  default     = ""
}

variable "bucket_name_mount_helper" {
  description = "The name of the bucket to fetch what is necessary for user-data.sh"
  type        = string
}

variable "aws_region" {
  description = "The region of the credentials"
  type        = string
  sensitive   = true
}

variable "aws_profile" {
  description = "The profile of the credentials"
  type        = string
  sensitive   = true
}

variable "aws_access_key" {
  description = "the public key of the access credentials"
  type        = string
  sensitive   = true
}

variable "aws_secret_key" {
  description = "the private key of the access credentials"
  type        = string
  sensitive   = true
}

# Mongodb
variable "mongodb_version" {
  description = "The version of the database"
  type        = string
}

# EC2
variable "server_port" {
  description = "The port of the server to forward the traffic to"
  type        = number
}

variable "health_check_path" {
  description = "The path to forward the traffic to"
  type        = string
}

variable "ami_name" {
  description = "The name of the AMI used for the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "The type of EC2 Instances to run (e.g. t2.micro)"
  type        = string
}
