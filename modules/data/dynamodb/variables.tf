variable "common_tags" {
  description = "Custom tags to set on the Instances in the ASG"
  type        = map(string)
  default     = {}
}

variable "table_name" {
  description = "The name of the table"
  type        = string
}

variable "primary_key_name" {
  description = "The name of the primary key"
  type        = string
}

variable "primary_key_type" {
  description = "The type of the  primary key"
  type        = string
}

variable "sort_key_name" {
  description = "The name of the  sort key"
  type        = string
}

variable "sort_key_type" {
  description = "The type of the  sort key"
  type        = string
}

variable "autoscaling" {
  description = "Enable autoscaling, it will add cloudwatch alarms"
  type        = bool
  default     = false
}
