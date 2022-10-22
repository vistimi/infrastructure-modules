# Global

variable "cluster_name" {
  description = "The name of the EC2 cluster"
  type        = string
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