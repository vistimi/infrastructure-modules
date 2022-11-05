# Global
variable "aws_region" {
  description = "The region on which the project is running, (e.g `us-east-1`)"
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
