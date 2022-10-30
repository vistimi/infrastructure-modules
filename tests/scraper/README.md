# scraper

Variables:
```
region                   = "us-east-1"
project_name             = "scraper"
environment_name         = "test"
vpc_cidr_ipv4            = "1.0.0.0/16"
```

Outputs:
```
default_security_group_id = "sg-065fe4857db2112d9"
private_subnets = [
  "subnet-0f0c2f4eb7a73ae75",
  "subnet-05561191ab56acaec",
  "subnet-014b7854a7e66f5ef",
]
public_subnets = [
  "subnet-053af9be74486bdec",
  "subnet-09a00f6bc7a216def",
  "subnet-06a9db64287e77a76",
]
vpc_id = "vpc-0ef51aa8c677274ce"
```