output "microservice" {
  value = module.microservice
}

output "dynamodb_tables" {
  value = {
    for key, db in module.dynamodb_table : key => db
  }
}

output "bucket_picture" {
  value = {
    bucket = module.bucket_picture
    policy_attached = {
      id          = aws_iam_policy.bucket_picture.id
      arn         = aws_iam_policy.bucket_picture.arn
      description = aws_iam_policy.bucket_picture.description
      name        = aws_iam_policy.bucket_picture.name
      path        = aws_iam_policy.bucket_picture.path
      policy      = aws_iam_policy.bucket_picture.policy
      policy_id   = aws_iam_policy.bucket_picture.policy_id
      tags_all    = aws_iam_policy.bucket_picture.tags_all
    }
  }
}
