# Create backup before doing any changes
# plan before changes

locals {
  config = {
    scraper = {
      frontend = yamldecode(file("${var.root_path}/projects/module/aws/microservice/scraper-frontend/config.yml"))
      backend  = yamldecode(file("${var.root_path}/projects/module/aws/microservice/scraper-backend/config.yml"))
    }
  }

  microservice_config = yamldecode(file("${var.root_path}/projects/module/aws/microservice/config.yml"))

  statements = flatten(concat(
    [
      for statement in local.microservice_config.statements : [
        for sid, value in statement : {
          sid        = title(sid)
          actions    = try(value.actions, [])
          effect     = try(value.effect, null)
          resources  = try(value.resources, [])
          conditions = try(value.conditions, [])
        }
      ]
    ],
    [
      for project_name in var.project_names : [
        for service_name, microservice_config in local.config[project_name] : [
          for statement in microservice_config.statements : [
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
