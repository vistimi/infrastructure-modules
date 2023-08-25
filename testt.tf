module "microservice" {
  source = "./module/aws/container/microservice"

  vpc = {
    id   = "vpc-013a411b59dd8a08e"
    tier = "public"
  }

  iam = {
    scope        = "accounts"
    requires_mfa = false
  }

  name = "testt"

  container = {
    group = {
      deployment = {
        min_size        = 1
        max_size        = 1
        desired_size    = 1
        maximum_percent = 30
      }
      ec2 = {
        # key_name = nil
        instance_types = ["t3.small"]
        os             = "linux"
        os_version     = "2"
        architecture   = "x86_64"
        capacities = [
          {
            type = "ON_DEMAND"
          }
        ]
      }
    }
    traffics = [{
      listener = {
        port     = 80
        protocol = "http"
      }
      target = {
        port     = 80
        protocol = "http"
      }
    }]
    eks = {
      cluster_version = "1.27"
    }
  }

  tags = {}
}

output "microservice" {
  value = module.microservice
}
