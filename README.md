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

```terraform
resource "aws_resource_type" "resource_name" {
  tags = merge(var.common_tags, {Name="..."})
}
```

Add the lifecycle policy to create before detroying to avoid downtime:

```terraform
resource "aws_resource_type" "resource_name" {
  lifecycle {
    create_before_destroy = true
  }
}
```

## env

#### devcontainer

```
AWS_REGION=***
AWS_PROFILE=***
AWS_ACCESS_KEY=***
AWS_SECRET_KEY=***
```

## variables

Variables set in the file can be overridden at deployment:

```shell
terraform apply -var <var_to_change>=<new_value>
```