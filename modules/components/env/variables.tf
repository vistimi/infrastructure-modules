# Global
variable "account_id" {
  description = "The ID of the AWS account"
  type        = string
}

variable "bucket_name" {
  description = "The name of the bucket"
  type        = string
}

variable "common_tags" {
  description = "Custom tags to set on the Instances in the ASG"
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
}

variable "source_arns" {
  description = "The ARNs of the sources that have access to this bucket"
  type        = list(string)
}
