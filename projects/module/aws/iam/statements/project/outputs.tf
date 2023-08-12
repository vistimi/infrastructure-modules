output "statements" {
  value = local.statements
}

output "project_lists" {
  value = local.project_lists
}

output "repository_file_exists" {
  value = local.repository_file_exists
}

output "microservice_file_exist" {
  value = local.microservice_file_exist
}

output "json" {
  value = data.aws_iam_policy_document.check.json
}
