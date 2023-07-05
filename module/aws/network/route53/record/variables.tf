variable "zone_name" {
  description = "The name of the zone"
  type        = string
}

variable "subdomain_name" {
  description = "The record name prefixed to the zone name"
  type        = string
}

variable "alias_name" {
  description = "Url of the record"
  type        = string
}

variable "alias_zone_id" {
  description = "Zone id of the record"
  type        = string
}
