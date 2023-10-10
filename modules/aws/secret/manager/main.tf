resource "aws_secretsmanager_secret" "this" {

  name = var.name

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "this" {

  secret_id     = aws_secretsmanager_secret.this.id
  secret_string = jsonencode({ for secret in var.secrets : secret.key => sensitive(secret.value) })
}
