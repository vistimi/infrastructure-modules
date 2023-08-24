# ec2 and fargate inside group
variable "eks" {
  type = object({
    cluster_version = string
    groups = map(object({
      min_size                   = number
      max_size                   = number
      desired_size               = number
      deployment_maximum_percent = optional(number)
      ec2 = optional(object({
        key_name       = optional(string)
        instance_types = list(string)
        os             = string
        os_version     = string
        architecture   = string
        use_spot       = bool
      }))
    }))
  })
}


variable "name" {
  description = "The common part of the name used for all resources"
  type        = string
}

variable "tags" {
  description = "Custom tags to set on the Instances in the ASG"
  type        = map(string)
  default     = {}
}

variable "vpc" {
  type = object({
    id   = string
    tier = string
  })
}

# resource "null_resource" "deployment_type" {
#   lifecycle {
#     precondition {
#       condition     = contains(["fargate", "ec2"], var.service.deployment_type)
#       error_message = "EC2 deployment type must be one of [fargate, ec2]"
#     }
#   }
# }

# #--------------
# # ELB & ECS
# #--------------
# variable "route53" {
#   type = object({
#     zones = list(object({
#       name = string
#     }))
#     record = object({
#       prefixes       = optional(list(string))
#       subdomain_name = string
#     })
#   })
#   default = null
# }

# # https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html#target-group-protocol-version
# variable "traffics" {
#   type = list(object({
#     listener = object({
#       protocol         = string
#       port             = optional(number)
#       protocol_version = optional(string)
#     })
#     target = object({
#       protocol          = string
#       port              = number
#       protocol_version  = optional(string)
#       health_check_path = optional(string)
#       status_code       = optional(string)
#     })
#     base = optional(bool)
#   }))

#   validation {
#     condition     = length(var.traffics) > 0
#     error_message = "traffic must have at least one element"
#   }

#   validation {
#     condition     = length([for traffic in var.traffics : traffic.base if traffic.base == true || length(var.traffics) == 1]) == 1
#     error_message = "traffics must have exactly one base or only one element (base not required)"
#   }
#   validation {
#     condition     = length(distinct([for traffic in var.traffics : { listener = traffic.listener, target = traffic.target }])) == length(var.traffics)
#     error_message = "traffics elements cannot be similar"
#   }
# }

# resource "null_resource" "listener" {

#   for_each = {
#     for traffic in var.traffics :
#     join("-", compact([traffic.listener.protocol, traffic.listener.port, traffic.target.protocol, traffic.target.port])) => traffic.listener
#   }

#   lifecycle {
#     precondition {
#       condition     = contains(["http", "https", "tcp"], each.value.protocol)
#       error_message = "Listener protocol must be one of [http, https, tcp]"
#     }
#     precondition {
#       condition     = each.value.protocol_version != null ? contains(["http", "http2", "grpc"], each.value.protocol_version) : true
#       error_message = "Listener protocol version must be one of [http, http2, grpc] or null"
#     }
#   }
# }

# resource "null_resource" "target" {

#   for_each = {
#     for traffic in var.traffics :
#     join("-", compact([traffic.listener.protocol, traffic.listener.port, traffic.target.protocol, traffic.target.port])) => traffic.target
#   }

#   lifecycle {
#     precondition {
#       condition     = contains(["http", "https", "tcp"], each.value.protocol)
#       error_message = "Target protocol must be one of [http, https, tcp]"
#     }
#     precondition {
#       condition     = each.value.protocol_version != null ? contains(["http", "http2", "grpc"], each.value.protocol_version) : true
#       error_message = "Target protocol version must be one of [http, http2, grpc] or null"
#     }
#   }
# }
