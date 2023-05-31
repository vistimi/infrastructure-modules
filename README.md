# infrastructure-modules



## build

```shell
eval COMMON_NAME=infrastrucutre-modules-common; \
eval NAME=infrastrucutre-modules; \
sudo docker build -t $COMMON_NAME -f Dockerfile.common .; \
sudo docker build -t $NAME -f Dockerfile --build-arg="VARIANT=$COMMON_NAME" .; \
sudo docker run --rm -it --name $NAME --env-file .devcontainer/devcontainer.env $NAME
```

## devcontainer

```
AWS_REGION=***
AWS_PROFILE=***
AWS_ID=***
AWS_ACCESS_KEY=***
AWS_SECRET_KEY=***
ENVIRONMENT_NAME=local
GH_TERRA_TOKEN=***
```

In [Github](https://github.com/settings/personal-access-tokens/new):
:warning: The `GITHUB_TOKEN` is a default name

`GH_TERRA_TOKEN`:
```
Repository access
  Only select repositories: [scraper-backend, scraper-frontend, ...]

Repository permissions
  Actions: Read and write
  Contents: Read-only
  Environments: Read and write
  Metadata: Read-only
  Secrets: Read and write
  Variables: Read and write
```

`GH_INFRA_TOKEN`:
```
Repository access
  Only select repositories: [infrastructure-modules]

Repository permissions
  Contents: Read-only
  Metadata: Read-only
```

In [AWS]():

# Github

Repo secrets:
- GH_TERRA_TOKEN

Environment secrets:
- AWS_ACCESS_KEY
- AWS_SECRET_KEY

Environment variables:
- AWS_REGION
- AWS_ACCOUNT_ID
- AWS_PROFILE

# terraform

## run

Open the project with the dev container.

Check the commands of [terraform CLI](https://www.terraform.io/cli/commands#switching-working-directory-with-chdir).

```shell
# format
terraform fmt

# steps to create infrastructure
terraform init
terraform validate
terraform plan
terraform apply

# inspect
terraform show
terraform output

# destroy the infrastructure
terraform destroy
```

<details><summary> <b>Links</b> </summary>

Check the [tutorial for AWS](https://learn.hashicorp.com/tutorials/terraform/aws-build?in=terraform/aws-get-started).
To setup a VPC check this [Medium article](# https://medium.com/swlh/creating-an-aws-ecs-cluster-of-ec2-instances-with-terraform-85a10b5cfbe3
).
To setup workflow and environments check this [Medium article](https://blog.gruntwork.io/how-to-manage-terraform-state-28f5697e68fa).

Check the [HCL](https://developer.hashicorp.com/terraform/language).

</details>

<details><summary> <b>Code</b> </summary>

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
provider "aws" {
  aws_region = var.aws_region
}
```

</details>

# terragrunt

#### dependencies

[Docs](https://terragrunt.gruntwork.io/docs/features/execute-terraform-commands-on-multiple-modules-at-once/#dependencies-between-modules)

```shell
terragrunt graph-dependencies | dot -Tsvg > graph.svg
```

## variables

Variables set in the file can be overridden at deployment:

```shell
terraform apply -var <var_to_change>=<new_value>
```

## vpc
#### tier

Use the tag to access with `data` the desired outputs from specific subnets, `Private` or `Public`:

```hcl
data "aws_subnets" "tier" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  tags = {
    Tier = var.vpc_tier
  }
}
```

#### cidr

Using `/16` for CIDR blocks means that the last two parts of the adress are customizable for subnets.

The recommendations are to use the first part of the CIDR for different VPCs projects. When ever there should be a clear abstraction, use a different number. The recommendation is to simply increment by 1 the value of the first value of the CIDR, e.g. `10.0.0.0/16` to `11.0.0.0/16`.

The second part of the cidr block is reserved for replicas of an environment. It could be for another region, for a new environment. `10.0.0.0/16` to `10.1.0.0/16`


To check the first and last ip of a CIDR block:

```hcl
cidrhost("192.168.0.0/16", 0)
cidrhost("192.168.0.0/16", -1)
```

- 1.0.0.0/16 scraper test



# terratest 

  - make prepare
  - run each test
  - make clean

### local

Use the `RunTestStage` functionnality to disable certain parts of the code, thus not needing to constantly destroy and redeploy the instances for the same test:

```hcl
defer func() {
    if r := recover(); r != nil {
        // destroy all resources if panic
        terraform.Destroy(t, terraformOptions)
    }
    terratest_structure.RunTestStage(t, "cleanup_mongodb", func() {
        terraform.Destroy(t, terraformOptions)
    })
}()
terratest_structure.RunTestStage(t, "deploy_mongodb", func() {
    terraform.InitAndApply(t, terraformOptions)
})
terratest_structure.RunTestStage(t, "validate_mongodb", func() {
    s3bucketMongodbArn := terraform.Output(t, terraformOptions, "s3_bucket_mongodb_arn")
    s3bucketpicturesArn := terraform.Output(t, terraformOptions, "s3_bucket_pictures_arn")
    assert.Equal(t, fmt.Sprintf("arn:aws:s3:::%s", bucket_name_mongodb), s3bucketMongodbArn)
    assert.Equal(t, fmt.Sprintf("arn:aws:s3:::%s", bucket_name_pictures), s3bucketpicturesArn)
    err := testMongodbOperations()
    assert.Equal(t, nil, err)
})
```

If you need to disable one functionality, it needs to be present in the test so make sure the env is declared in the environment:

```shell
export SKIP_cleanup_mongodb=true
```

If you need to enable one functionality:

```shell
unset SKIP_cleanup_mongodb
```

# graphs

#### VPC

![VPC](modules/vpc/graph.png)

#### MongoDB

![MongoDB](modules/data/mongodb/graph.png)

#### scraper-backend

![Scraper-backend](modules/services/scraper-backend/graph.png)