output "repository" {
  value = {
    arn         = module.ecr.repository_arn
    registry_id = module.ecr.repository_registry_id
    url         = module.ecr.repository_url
  }
}
