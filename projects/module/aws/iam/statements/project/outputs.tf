output "statements" {
  value = local.statements
}

output "json" {
  value = data.aws_iam_policy_document.check.json
}
