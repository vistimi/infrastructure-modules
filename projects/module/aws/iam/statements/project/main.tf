# Create backup before doing any changes
# plan before changes

locals {
  config = {
    scraper = {
      frontend = {
        microservice = yamldecode(templatefile("${var.root_path}/projects/module/aws/microservice/config.yml", {
          name            = join("-", ["scraper-frontend", var.user_name, var.branch_name])
          repository_name = join("-", ["scraper-frontend", var.branch_name])
        }))
        repository = yamldecode(templatefile("${var.root_path}/projects/module/aws/microservice/scraper-frontend/config.yml", {
        }))
      }
      backend = {
        microservice = yamldecode(templatefile("${var.root_path}/projects/module/aws/microservice/config.yml", {
          name            = join("-", ["scraper-backend", var.user_name, var.branch_name])
          repository_name = join("-", ["scraper-backend", var.branch_name])
        }))
        repository = yamldecode(templatefile("${var.root_path}/projects/module/aws/microservice/scraper-backend/config.yml", {
          name                = join("-", ["scraper-backend", var.user_name, var.branch_name])
          bucket_picture_name = "picture"
        }))
      }
    }
  }

  statements = flatten(
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
  )
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
