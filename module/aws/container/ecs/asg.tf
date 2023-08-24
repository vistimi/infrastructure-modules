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
  for_each = {
    for key, value in var.ec2 :
    key => {
      name = local.ami_ssm_name[join("-", ["amazon", value.os, value.os_version, value.architecture])]
    }
    if var.service.deployment_type == "ec2"
  }

  name = each.value.name
}

locals {
  image_ids = {
    for key, value in var.ec2 :
    key => data.aws_ssm_parameter.ecs_optimized_ami_id[key].value if var.service.deployment_type == "ec2"
  }

  # https://github.com/aws/amazon-ecs-agent/blob/master/README.md
  # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-gpu.html
  # <<- is required compared to << because there should be no identation for EOT and EOF to work properly
  user_data = {
    for key, value in var.ec2 : key => <<-EOT
        #!/bin/bash
        cat <<'EOF' >> /etc/ecs/ecs.config
        ECS_CLUSTER=${var.name}
        ${value.use_spot ? "ECS_ENABLE_SPOT_INSTANCE_DRAINING=true" : ""}
        ECS_ENABLE_TASK_IAM_ROLE=true
        ${value.architecture == "gpu" ? "ECS_ENABLE_GPU_SUPPORT=true" : ""}
        ${value.architecture == "gpu" ? "ECS_NVIDIA_RUNTIME=nvidia" : ""}
        EOF
        ${value.user_data != null ? value.user_data : ""}
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
    for key, value in var.ec2 :
    key => {
      name              = "${var.name}-${key}"
      capacity_provider = value.capacity_provider
      use_spot          = value.use_spot
      instance_type     = value.instance_type
      key_name          = value.key_name # to SSH into instance
      instance_refresh  = value.asg.instance_refresh
    } if var.service.deployment_type == "ec2"
  }

  vpc = var.vpc

  name              = each.value.name
  capacity_provider = each.value.capacity_provider
  instance_type     = each.value.instance_type
  key_name          = each.value.key_name
  instance_refresh  = each.value.instance_refresh
  use_spot          = each.value.use_spot

  image_id                 = local.image_ids[each.key]
  user_data_base64         = base64encode(local.user_data[each.key])
  weight_total             = sum([for key, value in var.ec2 : value.capacity_provider.weight])
  port_mapping             = "dynamic"
  layer7_to_layer4_mapping = local.layer7_to_layer4_mapping
  traffics                 = local.traffics
  target_group_arns        = module.elb.elb.target_group_arns
  source_security_group_id = module.elb.elb_sg.security_group_id

  min_count     = var.service.min_count
  max_count     = var.service.max_count
  desired_count = var.service.desired_count

  tags = var.tags
}

resource "aws_autoscaling_attachment" "ecs" {
  for_each = {
    for key, _ in var.ec2 :
    key => {}
    if var.service.deployment_type == "ec2"
  }
  autoscaling_group_name = module.asg[each.key].asg.autoscaling_group_name
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
