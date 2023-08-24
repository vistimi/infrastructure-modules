module "eks" {
  source = "./module/aws/container/eks"



  vpc = {
    id   = "vpc-013a411b59dd8a08e"
    tier = "public"
  }

  name = "testt"
  tags = {}
  eks = {
    cluster_version = "1.27"
    groups = {
      ng1test = {
        min_size                   = 1
        max_size                   = 1
        desired_size               = 1
        deployment_maximum_percent = 30
        ec2 = {
          # key_name = nil
          instance_types = ["t3.small"]
          os             = "linux"
          os_version     = "2"
          architecture   = "x86_64"
          use_spot       = false
        }
      }
    }
  }
}

output "eks" {
  value = module.eks
}
