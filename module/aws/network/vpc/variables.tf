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

resource "null_resource" "cidr_ipv4" {
  lifecycle {
    precondition {
      condition     = regex("^(?P<ip>[\\d\\.]+)\\/(?P<size>\\d+)?", var.cidr_ipv4).size == "16"
      error_message = "cidr ${jsonencode(regex("^(?P<ip>[\\d\\.]+)\\/(?P<size>\\d+)?", var.cidr_ipv4))} must have a block of size 16"
    }
  }
}

variable "nat" {
  description = "Enable the NAT gateway"
  type        = string
  default     = null

  validation {
    condition     = contains(["vpc", "az", "subnet"], var.nat)
    error_message = "nat must be in [vpc, az, subnet] or null"
  }
}

variable "tier_tags" {
  description = "vpc tier tags"
  type        = list(string)

  default = ["private", "public"]
}
