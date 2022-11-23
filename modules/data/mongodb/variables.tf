# Global
variable "data_storage_name" {
  description = "The name of the data storage"
  type        = string
}

variable "vpc_id" {
  description = "The IDs of the VPC which contains the subnets"
  type        = string
}

variable "vpc_cidr_block" {
  description = "The CIDR block of the Default VPC"
  type        = string
}

# variable "private_subnets" {
#   description = "List of IDs of private subnets"
#   type        = list(string)
# }

# variable "public_subnets" {
#   description = "List of IDs of public subnets"
#   type        = list(string)
# }

variable "vpc_security_group_ids" {
  description = "The IDs of the security group of the VPC"
  type        = list(string)
}

variable "common_tags" {
  description = "Custom tags to set on the Instances in the ASG"
  type        = map(string)
  default     = {}
}

variable "force_destroy" {
  description = "Force destroy non-empty buckets or other resources"
  type        = bool
}

# EC2
variable "ami_id"{
  description = "The ID of the AMI used for the EC2 instance"
  type        = string
  default = "ami-09d3b3274b6c5d4aa"
}

variable "instance_type" {
  description = "The type of EC2 Instances to run (e.g. t2.micro)"
  type        = string
}

variable "user_data_path" {
  description = "Bash script path to run after creation of instance"
  type        = string
  default     = ""
}

variable "user_data_args" {
  description = "Bash script arguments to pass to the bash script"
  type        = map(any)
  default     = {}
}

variable "bastion" {
  description = "Spawn a public EC2 instance in the same region as Mongodb EC2 instance"
  type        = bool
  default     = false
}

variable "aws_access_key" {
  description = "The public key for AWS"
  type        = string
  sensitive = true
}

variable "aws_secret_key" {
  description = "The private key for AWS"
  type        = string
  sensitive = true
}
