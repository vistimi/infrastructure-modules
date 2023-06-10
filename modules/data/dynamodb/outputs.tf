output "dynamodb" {
  value = {
    table_arn          = module.dynamodb_table.dynamodb_table_arn
    table_id           = module.dynamodb_table.dynamodb_table_id
    table_stream_arn   = module.dynamodb_table.dynamodb_table_stream_arn
    table_stream_label = module.dynamodb_table.dynamodb_table_stream_label
  }
}
