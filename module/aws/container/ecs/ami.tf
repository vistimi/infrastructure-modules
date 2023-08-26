locals {
  # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/retrieve-ecs-optimized_AMI.html
  ami_ssm_name = {
    amazon-linux-2-x86_64-cpu = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
    amazon-linux-2-x86_64-gpu = "/aws/service/ecs/optimized-ami/amazon-linux-2/gpu/recommended/image_id"
    amazon-linux-2-x86_64-inf = "/aws/service/ecs/optimized-ami/amazon-linux-2/inf/recommended/image_id"

    amazon-linux-2-arm64-cpu = "/aws/service/ecs/optimized-ami/amazon-linux-2/arm64/recommended/image_id"
    amazon-linux-2-arm64-gpu = "/aws/service/ecs/optimized-ami/amazon-linux-2/gpu/recommended/image_id"
    amazon-linux-2-arm64-inf = "/aws/service/ecs/optimized-ami/amazon-linux-2/inf/recommended/image_id"

    amazon-linux-2023-x86_64-cpu = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
    # amazon-linux-2023-x86_64-gpu   = "/aws/service/ecs/optimized-ami/amazon-linux-2023/gpu/recommended/image_id"
    amazon-linux-2023-x86_64-inf = "/aws/service/ecs/optimized-ami/amazon-linux-2023/inf/recommended/image_id"

    amazon-linux-2023-arm64 = "/aws/service/ecs/optimized-ami/amazon-linux-2023/arm64/recommended/image_id"
    # amazon-linux-2023-arm-gpu   = "/aws/service/ecs/optimized-ami/amazon-linux-2023/gpu/recommended/image_id"
    amazon-linux-2023-arm64-inf = "/aws/service/ecs/optimized-ami/amazon-linux-2023/inf/recommended/image_id"

    amazon-bottlerocket-latest-x86_64-cpu = "/aws/service/bottlerocket/aws-ecs-1/x86_64/latest/image_id"
    amazon-bottlerocket-latest-x86_64-gpu = "/aws/service/bottlerocket/aws-ecs-1-nvidia/x86_64/latest/image_id"

    amazon-bottlerocket-latest-arm64-cpu = "/aws/service/bottlerocket/aws-ecs-1/arm64/latest/image_id"
    amazon-bottlerocket-latest-arm64-gpu = "/aws/service/bottlerocket/aws-ecs-1-nvidia/arm64/latest/image_id"
  }
}

# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html#ecs-optimized-ami-linux
data "aws_ssm_parameter" "ecs_optimized_ami_id" {
  # TODO: handle no ec2
  name = local.ami_ssm_name[join("-", ["amazon", var.eks.group.ec2.os, var.eks.group.ec2.os_version, var.eks.group.ec2.architecture, var.eks.group.ec2.processor])]
}

locals {
  image_id = data.aws_ssm_parameter.ecs_optimized_ami_id.value
}
