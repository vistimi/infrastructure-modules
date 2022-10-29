# infrastructure

## run

Open the project with the dev container.

Check the commands of [terraform CLI](https://www.terraform.io/cli/commands#switching-working-directory-with-chdir).

```shell
# format
terraform -chdir=scraper fmt

# steps to create infrastructure
terraform init
terraform validate
terraform plan
terraform apply
terraform show

# destroy the infrastructure
terraform destroy
```

## terraform

<details><summary> <b>Links</b> </summary>

Check the [tutorial for AWS](https://learn.hashicorp.com/tutorials/terraform/aws-build?in=terraform/aws-get-started).
To setup a VPC check this [Medium article](# https://medium.com/swlh/creating-an-aws-ecs-cluster-of-ec2-instances-with-terraform-85a10b5cfbe3
).
To setup workflow and environments check this [Medium article](https://blog.gruntwork.io/how-to-manage-terraform-state-28f5697e68fa).

Check the [HCL](https://developer.hashicorp.com/terraform/language).

</details>

For reources tags, where `common_tags` is a map:

```hcl
resource "aws_resource_type" "resource_name" {
  tags = merge(var.common_tags, {Name="..."})
}
```

Add the lifecycle policy to create before detroying to avoid downtime.
Be careful not to do it on unique resources that cannot be duplicated.

```hcl
resource "aws_resource_type" "resource_name" {
  lifecycle {
    create_before_destroy = true
  }
}
```

Add the lifecycle policy to protect from destroying it:
```hcl
resource "aws_resource_type" "resource_name" {
  lifecycle {
    prevent_destroy = true
  }
}
```

For backing up the state in an S3 bucket, insert those only in the running terraform file, which would not be in `modules`. 
The backend name is usually `backend_name="terraform-state-backend"`.
There is a different state for production and non-production environments.

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"

  backend "s3" {
    bucket         = "terraform-state-backend-storage"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-backend-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region
}
```

For running a bash script after the creation of the resource:
```hcl
resource "aws_resource_type" "resource_name" {
  user_data = templatefile("user-data.sh", {
    var_to_inject = "something"
  })
}
```

Inside `user-data.sh`:

```shell
#!/bin/bash

...
${db_address}
...
```

## env

#### devcontainer

```
AWS_REGION=***
AWS_PROFILE=***
AWS_ACCESS_KEY=***
AWS_SECRET_KEY=***
TF_VAR_AWS_REGION="${AWS_REGION}"
TF_VAR_AWS_PROFILE="${AWS_PROFILE}"
TF_VAR_AWS_ACCESS_KEY="${AWS_ACCESS_KEY}"
TF_VAR_AWS_SECRET_KEY="${AWS_SECRET_KEY}"
```

## variables

Variables set in the file can be overridden at deployment:

```shell
terraform apply -var <var_to_change>=<new_value>
```

## cidr

Using `/16` for CIDR blocks means that the last two parts of the adress are customizable for subnets.
The recommendations are to use the first part of the CIDR for different VPCs projects. When ever there should be a clear abstraction, use a different number. The recommendation is to simply increment by 1 the value of the first value of the CIDR, e.g. `10.0.0.0/16` to `11.0.0.0/16`.
The second part of the cidr block is reserved for within the VPC for the different services running inside. `10.0.0.0/16` for one service and `10.1.0.0/16` for another one.


To check the first and last ip of a CIDR block:

```hcl
cidrhost("192.168.0.0/16", 0)
cidrhost("192.168.0.0/16", -1)
```