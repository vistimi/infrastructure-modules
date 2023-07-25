output "secrets" {
  value = {
    id       = aws_secretsmanager_secret.this.id
    arn      = aws_secretsmanager_secret.this.arn
    replica  = aws_secretsmanager_secret.this.replica
    tags_all = aws_secretsmanager_secret.this.tags_all
  }
}

output "versions" {
  value = {
    id         = aws_secretsmanager_secret_version.this.id
    arn        = aws_secretsmanager_secret_version.this.arn
    version_id = aws_secretsmanager_secret_version.this.version_id
  }
}
