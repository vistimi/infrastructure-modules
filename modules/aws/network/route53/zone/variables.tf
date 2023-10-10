variable "tags" {
  description = "Custom tags"
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "The IDs of the VPC which contains the subnets"
  type        = string
}

variable "name" {
  description = "The name of the domain that hosts the zone and records"
  type        = string
}

variable "comment" {
  description = "The comment of the zone"
  type        = string
}
