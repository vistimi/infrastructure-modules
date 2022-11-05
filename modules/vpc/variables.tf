variable "aws_region" {
  description = "The region on which the project is running, (e.g `us-east-1`)"
  type        = string
}

variable "vpc_name" {
  description = "The name of the VPC"
  type        = string
}

variable "common_tags" {
  description = "Custom tags to set on the Instances in the ASG"
  type        = map(string)
  default     = {}
}

variable "vpc_cidr_ipv4" {
  description = "The prefix of the vpc CIDR block (e.g. 160.0.0.0/16)"
  type        = string
}

# variable "vpc_availability_zones" {
#   description = "The number of availability zones to use"
#   type        = number
#   default     = 2
# }
