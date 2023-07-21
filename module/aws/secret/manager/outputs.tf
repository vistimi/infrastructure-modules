output "secrets" {
  value = {
    for name, secret in aws_secretsmanager_secret.these : name => {
      id       = secret.id
      arn      = secret.arn
      replica  = secret.replica
      tags_all = secret.tags_all
    }
  }
}

output "versions" {
  value = {
    for name, version in aws_secretsmanager_secret_version.these : name => {
      id         = version.id
      arn        = version.arn
      version_id = version.version_id
    }
  }
}
