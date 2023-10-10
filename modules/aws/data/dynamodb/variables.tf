variable "tags" {
  description = "Custom tags"
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

variable "predictable_workload" {
  description = "PROVISIONED billing mode for predictable workloads vs PAY_PER_REQUEST for unpredictable"
  type        = bool
  default     = true
}

variable "predictable_capacity" {
  description = "Enable autoscaling for predicatable workload, it will add cloudwatch alarms. The capacity is the read/write per second. The target is the CPU utilization % to reach for autoscaling"
  type = object({
    autoscaling = bool
    read = optional(object({
      capacity           = number
      scale_in_cooldown  = number
      scale_out_cooldown = number
      target_value       = number
      max_capacity       = number
      }), {
      capacity           = 5
      scale_in_cooldown  = 50
      scale_out_cooldown = 40
      target_value       = 45
      max_capacity       = 10
    })
    write = optional(object({
      capacity           = number
      scale_in_cooldown  = number
      scale_out_cooldown = number
      target_value       = number
      max_capacity       = number
      }), {
      capacity           = 5
      scale_in_cooldown  = 50
      scale_out_cooldown = 40
      target_value       = 45
      max_capacity       = 10
    })
  })

  default = {
    autoscaling = false
  }
}

variable "table_attachement_role_names" {
  description = "List of role names that will have access to this table"
  type        = list(string)
  default     = []
}

variable "iam" {
  type = object({
    scope        = string
    requires_mfa = optional(bool)
    mfa_age      = optional(number)
    account_ids  = optional(list(string))
    vpc_ids      = optional(list(string))
  })
}
