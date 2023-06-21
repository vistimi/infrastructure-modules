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
  }
}
