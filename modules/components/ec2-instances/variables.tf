# Global
variable "vpc_id" {
  description = "The IDs of the VPC which contains the subnets"
  type        = string
}

variable "subnets_ids" {
  description = "The IDs of the subnets for the ASG"
  type        = list(string)
}

variable "common_tags" {
  description = "Custom tags to set on the Instances in the ASG"
  type        = map(string)
  default     = {}
}

# EC2
# variable "cluster_name" {
#   description = "The name of the EC2 cluster"
#   type        = string
# }

# variable "server_port" {
#   description = "The port of the server to forward the traffic to"
#   type        = number
# }

# variable "health_check_path" {
#   description = "The path to forward the traffic to"
#   type        = string
# }

# variable "elb_port" {
#   description = "The port the ELB will use for HTTP requests"
#   type        = number
#   default     = 80
# }

# variable "ami_name" {
#   description = "The name of the AMI used for the EC2 instance"
#   type        = string
# }

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

# variable "public" {
#   description = "Are the resources public (e.g true) or private (e.g false)"
#   type        = bool
# }