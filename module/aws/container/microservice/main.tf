locals {
  tags = merge(var.tags, { VpcId = "${var.vpc.id}" })

  instances = {
    for instance_type in try(var.container.group.ec2.instance_types, []) :
    instance_type => {
      instance_prefix = regex("^(?P<prefix>\\w+)\\.(?P<size>\\w+)$", instance_type).prefix
      instance_size   = regex("^(?P<prefix>\\w+)\\.(?P<size>\\w+)$", instance_type).size
      instance_family = try(one(regex("(mac|u-|dl|trn|inf|vt|Im|Is|hpc)", regex("^(?P<prefix>\\w+)\\.(?P<size>\\w+)$", instance_type).prefix)), substr(instance_type, 0, 1))
    }
  }

  instances_arch = {
    for instance_type, instance_data in local.instances :
    instance_type => (
      contains(["t", "m", "c", "z", "u-", "x", "r", "dl", "trn", "f", "vt", "i", "d", "h", "hpc"], instance_data.instance_family) && contains(["", "i"], substr(instance_data.instance_prefix, length(instance_data.instance_family) + 1, 1)) ? "x86_64" : (
        contains(["t", "m", "c", "r", "i", "Im", "Is", "hpc"], instance_data.instance_family) && contains(["a", "g"], substr(instance_data.instance_prefix, length(instance_data.instance_family) + 1, 1)) ? "arm64" : (
          contains(["p", "g"], instance_data.instance_family) ? "gpu" : (
            contains(["inf"], instance_data.instance_family) ? "inf" : null
          )
        )
      )
    )
  }

  // TODO: add support for mac
  // gpu and inf both have cpus with either arm or x86 but the configuration doesn't require that to be specified
  instances_specs = {
    for instance_type, instance_data in local.instances : instance_type => {
      family                = instance_data.instance_family
      generation            = substr(instance_data.instance_prefix, length(instance_data.instance_family) + 0, 1)
      architecture          = local.instances_arch[instance_type]
      processor_family      = substr(instance_data.instance_prefix, length(instance_data.instance_family) + 1, 1)
      additional_capability = substr(instance_data.instance_prefix, length(instance_data.instance_family) + 2, -1)
      instance_size         = instance_data.instance_size
      processor_type = local.instances_arch[instance_type] == "gpu" ? "gpu" : (
        local.instances_arch[instance_type] == "inf" ? "inf" : "cpu"
      )
    }
  }
}
resource "null_resource" "instances" {
  lifecycle {
    precondition {
      condition     = length(distinct([for _, instance_specs in local.instances_specs : instance_specs.architecture])) == 1
      error_message = "instances need to have the same architecture: ${ { for instance_type, instance_specs in local.instances_specs : instance_type => instance_specs.architecture } }"
    }
  }
}

# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-types.html
# https://aws.amazon.com/ec2/instance-types/
resource "null_resource" "instance" {
  for_each = { for instance_type, instance_specs in local.instances_specs : instance_type => instance_specs }

  lifecycle {
    precondition {
      condition     = var.container.group.ec2.os == "linux" ? contains(["x86_64", "arm64", "gpu", "inf"], each.value.architecture) : false
      error_message = "EC2 architecture must for one of linux:[x86_64, arm64, gpu, inf]"
    }

    precondition {
      condition     = each.value.architecture == "gpu" ? var.container.group.container.gpu != null : true
      error_message = "EC2 gpu must have a task definition gpu number"
    }

    precondition {
      condition     = contains(["inf", "gpu"], each.value.processor_type) ? length(var.container.group.ec2.instance_types) == 1 : true
      error_message = "ec2 inf/gpu instance types must contain only one element, got ${jsonencode(var.container.group.ec2.instance_types)}"
    }
  }
}

module "ecs" {
  source = "../../../../module/aws/container/ecs"

  for_each = var.container.ecs != null ? { "${var.name}" = {} } : {}

  name     = var.name
  vpc      = var.vpc
  route53  = var.route53
  traffics = var.container.traffics
  ecs = {
    service = merge(
      var.container.group,
      {
        task = merge(
          var.container.group.deployment,
          try(var.container.ecs.service.task, {}),
          {
            container = merge(
              var.container.group.deployment.container,
              try(var.container.ecs.service.task.container, {}),
              {
                env_file = try({
                  bucket_name = one(values(module.bucket_env)).bucket.name
                  file_name   = var.bucket_env.file_key
                }, null)
              }
            )
          }
        )
        ec2 = merge(
          var.container.group.ec2,
          {
            architecture   = one(values(local.instances_specs)).architecture
            processor_type = one(values(local.instances_specs)).processor_type
          },
        )
      },
    )
  }

  tags = local.tags
}

module "eks" {
  source = "../../../../module/aws/container/eks"

  for_each = var.container.eks != null ? { "${var.name}" = {} } : {}

  name     = var.name
  vpc      = var.vpc
  route53  = var.route53
  traffics = var.container.traffics
  eks = merge(
    {
      create = var.container.eks != null ? true : false
      group = merge(
        var.container.group,
        {
          ec2 = merge(
            var.container.group.ec2,
            {
              architecture   = one(values(local.instances_specs)).architecture
              processor_type = one(values(local.instances_specs)).processor_type
            },
          ),
        },
      )
    },
    var.container.eks
  )

  tags = local.tags
}

# ------------------------
#     Bucket env
# ------------------------
module "bucket_env" {
  source = "../../../../module/aws/data/bucket"

  for_each = var.bucket_env != null ? { unique = {} } : {}

  name          = join("-", [var.name, var.bucket_env.name])
  force_destroy = var.bucket_env.force_destroy
  versioning    = var.bucket_env.versioning
  encryption = {
    enable = true
  }
  iam = {
    scope       = var.iam.scope
    account_ids = var.iam.account_ids
    vpc_ids     = var.iam.vpc_ids
  }

  tags = local.tags
}

resource "aws_s3_object" "env" {
  for_each = var.bucket_env != null ? { unique = {} } : {}

  key                    = var.bucket_env.file_key
  bucket                 = module.bucket_env[each.key].bucket.name
  source                 = var.bucket_env.file_path
  server_side_encryption = "aws:kms"
}
