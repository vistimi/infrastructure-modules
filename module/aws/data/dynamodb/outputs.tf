output "dynamodb" {
  value = {
    table_arn          = module.dynamodb_table.dynamodb_table_arn
    table_id           = module.dynamodb_table.dynamodb_table_id
    table_stream_arn   = module.dynamodb_table.dynamodb_table_stream_arn
    table_stream_label = module.dynamodb_table.dynamodb_table_stream_label
    policy_role_attachment = {
      id          = aws_iam_policy.role_attachment.id
      arn         = aws_iam_policy.role_attachment.arn
      description = aws_iam_policy.role_attachment.description
      name        = aws_iam_policy.role_attachment.name
      path        = aws_iam_policy.role_attachment.path
      policy      = aws_iam_policy.role_attachment.policy
      policy_id   = aws_iam_policy.role_attachment.policy_id
      tags_all    = aws_iam_policy.role_attachment.tags_all
    }
  }
}
