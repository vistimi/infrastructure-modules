variable "tags" {
  description = "Custom tags"
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "The IDs of the VPC which contains the subnets"
  type        = string
}

variable "zone" {
  type = object({
    name    = string
    comment = string
  })
}

variable "record" {
  type = object({
    subdomain_name = string
    alias_name     = string
    alias_zone_id  = string
  })
}
