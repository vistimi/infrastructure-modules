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

variable "enable_nat" {
  description = "Enable the NAT gateway"
  type        = bool
  nullable    = false
  default     = false
}

variable "tier_tags" {
  description = "vpc tier tags"
  type        = list(string)

  default = ["private", "public"]
}

resource "null_resource" "tier_tag_names" {
  lifecycle {
    precondition {
      condition     = contains(var.tier_tags, var.tier)
      error_message = "vpc tier must be one of ${jsonencode(var.tier_tags)}"
    }
  }
}
