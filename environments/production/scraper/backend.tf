terraform {
  backend "s3" {
    bucket         = "terraform-state-backend-production-storage"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-backend-production-locks"
    encrypt        = true
  }
}