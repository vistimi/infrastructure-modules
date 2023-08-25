locals {
  # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/retrieve-ecs-optimized_AMI.html
  ami_ssm_name = {
    amazon-linux-2-x86_64    = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
    amazon-linux-2-arm64     = "/aws/service/ecs/optimized-ami/amazon-linux-2/arm64/recommended/image_id"
    amazon-linux-2-gpu       = "/aws/service/ecs/optimized-ami/amazon-linux-2/gpu/recommended/image_id"
    amazon-linux-2-inf       = "/aws/service/ecs/optimized-ami/amazon-linux-2/inf/recommended/image_id"
    amazon-linux-2023-x86_64 = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
    amazon-linux-2023-arm64  = "/aws/service/ecs/optimized-ami/amazon-linux-2023/arm64/recommended/image_id"
    # amazon-linux-2023-gpu   = "/aws/service/ecs/optimized-ami/amazon-linux-2023/gpu/recommended/image_id"
    amazon-linux-2023-inf = "/aws/service/ecs/optimized-ami/amazon-linux-2023/inf/recommended/image_id"
  }
}

# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html#ecs-optimized-ami-linux
data "aws_ssm_parameter" "ecs_optimized_ami_id" {
  # TODO: handle no ec2
  name = local.ami_ssm_name[join("-", ["amazon", var.eks.group.ec2.os, var.eks.group.ec2.os_version, var.eks.group.ec2.architecture])]
}

locals {
  image_id = data.aws_ssm_parameter.ecs_optimized_ami_id.value

  # https://github.com/aws/amazon-ecs-agent/blob/master/README.md
  # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-gpu.html
  # <<- is required compared to << because there should be no identation for EOT and EOF to work properly
  user_data = {
    for capacity in var.ecs.service.ec2.capacities : capacity.type => <<-EOT
        #!/bin/bash
        cat <<'EOF' >> /etc/ecs/ecs.config
        ECS_CLUSTER=${var.name}
        ${capacity.type == "SPOT" ? "ECS_ENABLE_SPOT_INSTANCE_DRAINING=true" : ""}
        ECS_ENABLE_TASK_IAM_ROLE=true
        ${var.ecs.service.ec2.architecture == "gpu" ? "ECS_ENABLE_GPU_SUPPORT=true" : ""}
        ${var.ecs.service.ec2.architecture == "gpu" ? "ECS_NVIDIA_RUNTIME=nvidia" : ""}
        EOF
        ${var.ecs.service.ec2.user_data != null ? var.ecs.service.ec2.user_data : ""}
      EOT
  }

}

#------------------------
#     EC2 autoscaler
#------------------------
// TODO: support multiple instance_types
module "asg" {
  source = "../asg"

  for_each = {
    for obj in flatten([for instance_type in var.ecs.service.ec2.instance_types : [for capacity in var.ecs.service.ec2.capacities : {
      name          = "${var.name}-${capacity.type}-${instance_type}"
      instance_type = value.instance_type
      capacity      = capacity
      }
    ]]) : obj.name => { instance_type = obj.instance_type, capacity = obj.capacity }
  }

  name          = each.key
  instance_type = each.value

  capacity_provider = {
    weight = each.value.capacity.weight
  }
  capacity_weight_total = sum([for capacity in var.ecs.service.ec2.capacities : capacity.weight])
  key_name              = var.ecs.service.ec2.key_name
  instance_refresh      = var.ecs.service.ec2.instance_refresh
  use_spot              = each.value.capacity.type == "ON_DEMAND" ? false : true

  image_id                 = local.image_ids[each.key]
  user_data_base64         = base64encode(local.user_data[each.value.capacity.type])
  port_mapping             = "dynamic"
  layer7_to_layer4_mapping = local.layer7_to_layer4_mapping
  traffics                 = local.traffics
  target_group_arns        = module.elb.elb.target_group_arns
  source_security_group_id = module.elb.elb_sg.security_group_id

  vpc           = var.vpc
  min_count     = var.service.min_count
  max_count     = var.service.max_count
  desired_count = var.service.desired_count

  tags = var.tags
}

resource "aws_autoscaling_attachment" "ecs" {
  for_each               = module.asg
  autoscaling_group_name = each.value.asg.autoscaling_group_name
  lb_target_group_arn    = element(module.elb.elb.target_group_arns, 0)
}

# group notification
# resource "aws_autoscaling_notification" "webserver_asg_notifications" {
#   group_names = [
#     aws_autoscaling_group.webserver_asg.name,
#   ]
#   notifications = [
#     "autoscaling:EC2_INSTANCE_LAUNCH",
#     "autoscaling:EC2_INSTANCE_TERMINATE",
#     "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
#     "autoscaling:EC2_INSTANCE_TERMINATE_ERROR",
#   ]
#   topic_arn = aws_sns_topic.webserver_topic.arn
# }
# resource "aws_sns_topic" "webserver_topic" {
#   name = "webserver_topic"
# }
