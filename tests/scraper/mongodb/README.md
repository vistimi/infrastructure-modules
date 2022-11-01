```
region                 = "us-east-1"
subnet_id              = "subnet-053af9be74486bdec"
vpc_security_group_ids = ["sg-065fe4857db2112d9"]
vpc_id                 = "vpc-0ef51aa8c677274ce"
common_tags = {
  Region      = "us-east-1"
  Project     = "scraper"
  Environment = "test"
}
ami_id         = "ami-09d3b3274b6c5d4aa"
instance_type  = "t2.micro"
user_data_path = "mongodb.sh"
user_data_args = {
  bucket_name_mount_helper = "global-mount-helper"
  bucket_name_mongodb      = "bucket_name_mongodb"
  bucket_name_pictures     = "bucket_name_pictures"
  mongodb_version          = "6.0.1"
  aws_region               = ""
  aws_profile              = ""
  aws_access_key           = ""
  aws_secret_key           = ""
}
```