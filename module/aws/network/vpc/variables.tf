variable "name" {
  description = "The name of the VPC"
  type        = string
}

variable "tags" {
  description = "Custom tags to set on the Instances in the ASG"
  type        = map(string)
  default     = {}
}

variable "cidr_ipv4" {
  description = "The prefix of the vpc CIDR block (e.g. 160.0.0.0/16)"
  type        = string
}

variable "enable_nat" {
  description = "Enable the NAT gateway"
  type        = bool
  default     = false
}
