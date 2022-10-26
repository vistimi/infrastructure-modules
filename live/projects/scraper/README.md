# scraper

Should deploy `vpc`, `scraper-backend`, `scraper-frontend`.

The convention for the mongodb docker images is `mongodb.<version>.tar` with version being `6.0.1`.

```hcl

region            = "us-east-1"
project_name      = "scraper"
environment_name  = "trunk"
vpc_cidr_ipv4     = "160.0.0.0/16"
mongodb_version   = "6.0.1"
cluster_name      = "mongodb_ec2"
server_port       = "27017"
health_check_path = "/"
ami_name          = "aws-linux-2"
instance_type     = "t2.micro"
user_data_path    = "live/projects/scraper/user-data.sh"
# AWS_REGION = TF_VAR_AWS_REGION
# AWS_PROFILE = TF_VAR_AWS_PROFILE
# AWS_ACCESS_KEY with env TF_VAR_AWS_ACCESS_KEY
# AWS_SECRET_KEY with env TF_VAR_AWS_SECRET_KEY
```