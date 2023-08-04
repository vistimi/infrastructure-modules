# Create backup before doing any changes
# plan before changes

locals {
  config = {
    scraper = {
      frontend = yamldecode(file("../../microservice/scraper-frontend/config.yml"))
      backend  = yamldecode(file("../../microservice/scraper-backend/config.yml"))
    }
  }

  microservice_config = yamldecode(file("../../microservice/config.yml"))

  statements = concat(
    [
      for statement in local.microservice_config.statements : {
        actions    = try(statement.actions, [])
        effect     = try(statement.effect, null)
        resources  = try(statement.resources, [])
        conditions = try(statement.conditions, [])
      }
    ],
    [
      for project_name in var.project_names : [
        for project_config in local.config[project_name] : [
          for microservice_config in values(project_config) : [
            for statement in microservice_config.statements : {
              actions    = try(statement.actions, [])
              effect     = try(statement.effect, null)
              resources  = try(statement.resources, [])
              conditions = try(statement.conditions, [])
            }
          ]
        ]
      ]
    ]
  )
}
