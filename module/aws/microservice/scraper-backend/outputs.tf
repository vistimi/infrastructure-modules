output "microservice" {
  value = {
    ecs        = module.microservice.ecs
    vpc        = module.microservice.vpc
    bucket_env = module.microservice.bucket_env
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
