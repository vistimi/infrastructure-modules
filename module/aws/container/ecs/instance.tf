locals {
  # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/memory-management.html
  # https://docs.aws.amazon.com/cli/latest/reference/ecs/describe-container-instances.html
  instances_specs = {
    "t3.small" = {
      cpu              = 2048
      memory           = 2048
      memory_available = 1901
    }
    "t3.medium" = {
      cpu              = 2048
      memory           = 4096
      memory_available = 3828
    }
    "g4dn.xlarge" = {
      cpu              = 4096
      gpu              = 1
      memory           = 16384
      memory_available = 15731
    }
    "inf1.xlarge" = {
      cpu              = 4096
      memory           = 8192
      memory_available = 7667
      device_paths     = ["/dev/neuron0"] // AWS ML accelerator chips
    }
  }
}

resource "null_resource" "instances" {
  lifecycle {
    precondition {
      condition     = alltrue([for instance_type in var.ecs.service.ec2.instance_types : contains(keys(local.instances_specs), instance_type)])
      error_message = <<EOF
only supported instance types are: ${jsonencode(keys(local.instances_specs))}
got: ${jsonencode(var.ecs.service.ec2.instance_types)}
EOF
    }
  }
}
