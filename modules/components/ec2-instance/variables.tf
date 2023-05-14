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

variable "common_name" {
  description = "The common part of the name used for all resources"
  type        = string
}

variable "common_tags" {
  description = "Custom tags to set on the Instances in the ASG"
  type        = map(string)
  default     = {}
}

# EC2
variable "instance_type" {
  description = "The type of EC2 Instances to run (e.g. t2.micro)"
  type        = string
}

variable "associate_public_ip_address" {
  description = "Whether to associate a public IP address with an instance in a VPC"
  type        = bool
}

variable "user_data" {
  description = "The user data to provide when launching the instance. '#!/bin/bash\necho ECS_CLUSTER=my-cluster >> /etc/ecs/ecs.config' otherwise the instance will be launched in the default cluster"
  type        = string
  default     = null
}

variable "key_name" {
  description = "The name of the key for SSH"
  type        = string
  default     = null
}

variable "ami_ssm_architecture_spot" {
  description = "The name of the ssm name to select the optimized AMI architecture"
  type        = string
  default     = "amazon-linux-2"
}

variable "ami_ssm_name" {
  description = "Map to select an optimized ami for the correct architecture"
  type        = map(string)

  default = {
    amazon-linux-2       = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended"
    amazon-linux-2-arm64 = "/aws/service/ecs/optimized-ami/amazon-linux-2/arm64/recommended"
    amazon-linux-2-gpu   = "/aws/service/ecs/optimized-ami/amazon-linux-2/gpu/recommended"
  }
}
