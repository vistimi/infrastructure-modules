variable "name_prefix" {
  description = "The name prefix that comes after the microservice name"
  type        = string
  default     = ""
}

variable "name_suffix" {
  description = "The name suffix that comes after the config name"
  type        = string
}

variable "vpc" {
  type = object({
    id             = string
    existing_tiers = optional(list(string), ["private", "public", "intra"])
  })
}

variable "bucket_label" {
  type = object({
    force_destroy = optional(bool, false)
    versioning    = optional(bool, true)
  })
  nullable = false
  default  = {}
}

variable "route53" {
  type = object({
    zone = object({
      name = string
    })
    record = object({
      subdomain_name = string
    })
  })
  default = null
}

variable "iam" {
  type = object({
    scope       = string
    account_ids = optional(list(string))
    vpc_ids     = optional(list(string))
  })
}

# https://github.com/HumanSignal/label-studio-terraform/blob/master/terraform/aws/env/variables.tf
variable "labelstudio" {
  type = object({
    instance_type                         = optional(string, "t3.medium")
    desired_capacity                      = optional(number, 3)
    max_size                              = optional(number, 5)
    min_size                              = optional(number, 3)
    create_acm_certificate                = optional(bool, false)
    eks_capacity_type                     = optional(string, "ON_DEMAND")
    ingress_namespace                     = optional(string, "ingress")
    monitoring_namespace                  = optional(string, "monitoring")
    aws_auth_roles                        = optional(list(any), [])
    aws_auth_users                        = optional(list(any), [])
    aws_auth_accounts                     = optional(list(any), [])
    label_studio_helm_chart_repo          = optional(string, "https://charts.heartex.com")
    label_studio_helm_chart_repo_username = optional(string, "")
    label_studio_helm_chart_repo_password = optional(string, "")
    label_studio_helm_chart_name          = optional(string, "label-studio")
    label_studio_helm_chart_version       = optional(string, "1.0.16")
    label_studio_docker_registry_server   = optional(string, "https://index.docker.io/v2/")
    label_studio_docker_registry_username = optional(string, "")
    label_studio_docker_registry_password = optional(string, "")
    label_studio_docker_registry_email    = optional(string, "")
    label_studio_additional_set           = optional(map(string), {})
    enterprise                            = optional(bool, false)
    deploy_label_studio                   = optional(bool, true)
    license_literal                       = optional(string)
    postgresql_type                       = optional(string, "rds")
    postgresql_machine_type               = optional(string, "db.m5.large")
    postgresql_database                   = optional(string, "labelstudio")
    postgresql_host                       = optional(string, "")
    postgresql_port                       = optional(number, 5432)
    postgresql_username                   = optional(string, "labelstudio")
    postgresql_password                   = optional(string)
    postgresql_ssl_mode                   = optional(string, "require")
    postgresql_tls_key_file               = optional(string)
    postgresql_tls_crt_file               = optional(string)
    postgresql_ca_crt_file                = optional(string)
    redis_type                            = optional(string, "elasticache")
    redis_machine_type                    = optional(string, "cache.t3.micro")
    redis_host                            = optional(string, "")
    redis_port                            = optional(number, 6379)
    redis_password                        = optional(string)
    redis_ssl_mode                        = optional(string, "required")
    redis_ca_crt_file                     = optional(string)
    redis_tls_crt_file                    = optional(string)
    redis_tls_key_file                    = optional(string)
    lets_encrypt_email                    = optional(string)
    cluster_endpoint_public_access_cidrs  = optional(list(string), ["0.0.0.0/0"])
  })

  validation {
    condition     = contains(["rds"], var.labelstudio.postgresql_type) ? regex("^(?:(?P<usecase>\\w+)\\.)?(?P<prefix>\\w+)\\.(?P<size>\\w+)$", var.labelstudio.postgresql_machine_type).usecase == "db" : true
    error_message = "postgresql machine type needs to be of type db.<family>.<size>, got ${var.labelstudio.postgresql_machine_type}"
  }

  validation {
    condition     = contains(["elasticache"], var.labelstudio.postgresql_type) ? regex("^(?:(?P<usecase>\\w+)\\.)?(?P<prefix>\\w+)\\.(?P<size>\\w+)$", var.labelstudio.redis_machine_type).usecase == "cache" : true
    error_message = "redis machine type needs to be of type db.<family>.<size>, got ${var.labelstudio.redis_machine_type}"
  }
}

variable "tags" {
  description = "Custom tags to set on the Instances in the ASG"
  type        = map(string)
  default     = {}
}
