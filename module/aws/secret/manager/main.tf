resource "aws_secretsmanager_secret" "these" {
  for_each = { for name in var.names : name => {} }

  name = each.key

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "these" {
  for_each = { for name in var.names : name => {} }

  secret_id     = aws_secretsmanager_secret.these[each.key].id
  secret_string = jsonencode({ for secret in var.secrets : secret.key => sensitive(secret.value) })
}
