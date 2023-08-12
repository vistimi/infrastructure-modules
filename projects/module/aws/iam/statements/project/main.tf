data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  region_name = data.aws_region.current.name

  root_path     = trimsuffix(var.root_path, "/")
  projects_path = "${local.root_path}/projects/module/aws/projects"
  project_lists = {
    projects = {
      for project_name in compact(distinct(flatten([for _, v in flatten(fileset(local.projects_path, "**")) : try(regex("^(?P<dir>[0-9A-Za-z!_-]+)/+.*", dirname(v)).dir, "")]))) : project_name => {
        services = {
          for service_name in compact(distinct(flatten([for _, v in flatten(fileset(local.projects_path, "${project_name}/**")) : try(regex("^${project_name}/(?P<dir>[0-9A-Za-z!_-]+)/+.*", dirname(v)).dir, "")]))) : service_name => {
            path = "${local.projects_path}/${project_name}/${service_name}"
          }
        }
      }
    },
  }

  template_vars = {
    name_prefix         = length(var.name_prefix) > 0 ? "${var.name_prefix}-" : ""
    user_name           = var.user_name
    branch_name         = var.branch_name
    bucket_picture_name = "picture"
    bucket_env_name     = "env"
  }

  config_projects = {
    for project_name, project in try(yamldecode(file("${local.projects_path}/projects.yml")).projects, local.project_lists.projects) : project_name => {
      for service_name, service in try(project.services, local.project_lists[project_name].services) : service_name => {
        repository = yamldecode(
          templatefile("${try(service.path, local.project_lists[project_name].services[service_name].path)}/config.yml", local.template_vars)
        )
      }
    }
  }

  config = merge(
    {
      for project_name, project_config in local.config_projects : project_name => {
        for service_name, service_config in project_config : service_name => merge(
          service_config,
          try(service_config.repository.deployment_type, "") == "microservice" ? {
            microservice = yamldecode(templatefile("${local.projects_path}/microservice.yml", merge(local.template_vars, {
              project_name = service_config.repository.project_name
              service_name = service_config.repository.service_name
              })
            ))
          } : {},
        )
      }
    },
    {
      permission = {
        user = {
          statements = [
            {
              SelfMaintenance = {
                actions   = ["iam:ListMFADevices", "iam:CreateVirtualMFADevice", "iam:DeactivateMFADevice", "iam:ListAccessKeys"]
                effect    = "Allow"
                resources = ["arn:aws:iam::${local.account_id}:user/${var.user_name}"]
              },
              S3Backend = {
                actions   = ["s3:*"]
                effect    = "Allow"
                resources = ["arn:aws:s3:::*${var.user_name}*${var.backend.bucket_name}"]
              },
              DynamodbBackend = {
                actions   = ["dynamodb:*"]
                effect    = "Allow"
                resources = ["arn:aws:dynamodb:${local.region_name}:${local.account_id}:table/*${var.user_name}*${var.backend.bucket_name}"]
              },
            }
          ]
        }
      }
    },
  )

  statements = flatten(concat(
    [
      for project_name in ["permission"] : [
        for principal_name, configs in local.config[project_name] : [
          for statement in configs.statements : [
            for sid, value in statement : {
              sid        = format("%s%s%s", title(project_name), title(principal_name), title(sid))
              actions    = try(value.actions, [])
              effect     = try(value.effect, null)
              resources  = try(value.resources, [])
              conditions = try(value.conditions, [])
            }
          ]
        ]
      ]
    ],
    [
      for project_name in var.project_names : [
        for service_name, configs in local.config[project_name] : [
          for statement in concat(try(configs.microservice.statements, []), try(configs.repository.statements, [])) : [
            for sid, value in statement : {
              sid        = format("%s%s%s", title(project_name), title(service_name), title(sid))
              actions    = try(value.actions, [])
              effect     = try(value.effect, null)
              resources  = try(value.resources, [])
              conditions = try(value.conditions, [])
            }
          ]
        ]
      ]
    ]
  ))
}

data "aws_iam_policy_document" "check" {
  dynamic "statement" {
    for_each = local.statements

    content {
      sid       = statement.value.sid
      actions   = statement.value.actions
      resources = statement.value.resources
      effect    = statement.value.effect

      dynamic "condition" {
        for_each = statement.value.conditions
        content {
          test     = condition.value.test
          variable = condition.value.variable
          values   = condition.value.values
        }
      }
    }
  }
}
