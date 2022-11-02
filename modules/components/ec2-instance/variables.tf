# Global
# variable "vpc_id" {
#   description = "The IDs of the VPC which contains the subnets"
#   type        = string
# }

variable "subnet_id" {
  description = "The ID of the subnet for the EC2 instance"
  type        = string
}

variable "vpc_security_group_ids" {
  description = "The IDs of the security group of the VPC"
  type        = list(string)
}

variable "common_tags" {
  description = "Custom tags to set on the Instances in the ASG"
  type        = map(string)
  default     = {}
}

# EC2
variable "cluster_name" {
  description = "The name of the EC2 cluster"
  type        = string
}

# variable "server_port" {
#   description = "The port of the server to forward the traffic to"
#   type        = number
# }

# variable "health_check_path" {
#   description = "The path to forward the traffic to"
#   type        = string
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

# variable "public" {
#   description = "Are the resources public (e.g true) or private (e.g false)"
#   type        = bool
# }

variable "user_data_path" {
  description = "Bash script path to run after creation of instance"
  type        = string
  default     = ""
}

variable "user_data_args" {
  description = "Bash script arguments to pass to the bash script"
  type        = map
  default     = {}
}

variable "key_name" {
  description = "The name of the key for SSH"
  type        = string
}