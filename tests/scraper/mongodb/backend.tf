# terraform {
#   backend "s3" {
#     bucket         = "terraform-state-backend-test-storage"
#     key            = "global/s3/terraform.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "terraform-state-backend-test-locks"
#     encrypt        = true
#   }
# }