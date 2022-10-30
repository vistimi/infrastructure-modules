# scraper

Should deploy `vpc`, `scraper-backend`, `scraper-frontend`.

The convention for the mongodb docker images is `mongodb.<version>.tar` with version being `6.0.1`.

```hcl
region                   = "us-east-1"
project_name             = "scraper"
environment_name         = "production"
vpc_cidr_ipv4            = "1.0.0.0/16"
mongodb_version          = "6.0.1"
server_port              = "27017"
health_check_path        = "/"
ami_name                 = "aws-linux-2"
instance_type            = "t2.micro"
user_data_path           = "user-data.sh"
bucket_name_mount_helper = "global-mount-helper"
aws_region               = ""
aws_profile              = ""
aws_access_key           = ""
aws_secret_key           = ""
```