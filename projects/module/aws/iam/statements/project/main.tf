data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  template_vars = {
    project_name        = "scraper"
    service_name        = "frontend"
    user_name           = var.user_name
    branch_name         = var.branch_name
    bucket_picture_name = "picture"
    bucket_env_name     = "env"
  }
  config = {
    permission = {
      user = {
        statements = [
          {
            SelfMaintenance = {
              actions   = ["iam:ListMFADevices", "iam:CreateVirtualMFADevice", "iam:DeactivateMFADevice", "iam:ListAccessKeys"]
              effect    = "Allow"
              resources = ["arn:aws:iam::${local.account_id}:user/${var.user_name}"]
            }
          }
        ]
      }
    }
    scraper = {
      frontend = {
        microservice = yamldecode(templatefile("${var.root_path}/projects/module/aws/microservice/config.yml", merge(local.template_vars, {
          project_name = "scraper"
          service_name = "frontend"
          })
        ))
        repository = yamldecode(templatefile("${var.root_path}/projects/module/aws/microservice/scraper-frontend/config.yml", merge(local.template_vars, {
          project_name = "scraper"
          service_name = "frontend"
          })
        ))
      }
      backend = {
        microservice = yamldecode(templatefile("${var.root_path}/projects/module/aws/microservice/config.yml", merge(local.template_vars, {
          project_name = "scraper"
          service_name = "backend"
          })
        ))
        repository = yamldecode(templatefile("${var.root_path}/projects/module/aws/microservice/scraper-backend/config.yml", merge(local.template_vars, {
          project_name = "scraper"
          service_name = "backend"
          })
        ))
      }
    }
  }

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
