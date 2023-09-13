output "microservice" {
  value = {
    ecs        = module.microservice.ecs
    env = module.microservice.env
  }
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
