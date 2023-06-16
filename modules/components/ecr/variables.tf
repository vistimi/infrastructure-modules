variable "name" {
  description = "The name of the repository"
  type        = string
}

variable "tags" {
  description = "Custom tags"
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "The IDs of the VPC which contains the subnets"
  type        = string
}

variable "force_destroy" {
  description = "If true, will delete the resources that still contain elements"
  type        = bool
  default     = true
}

variable "image_keep_count" {
  description = "The amount of images to keep in the repository"
  type        = number
  default     = 1
}
