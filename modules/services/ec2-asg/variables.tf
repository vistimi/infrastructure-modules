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

variable "custom_tags" {
  description = "Custom tags to set on the Instances in the ASG"
  type        = map(string)
  default     = {}
}

# EC2

variable "instance_type" {
  description = "The type of EC2 Instances to run (e.g. t2.micro)"
  type        = string
}

variable "max_size" {
  description = "The maximum number of EC2 Instances in the ASG"
  type        = number
}