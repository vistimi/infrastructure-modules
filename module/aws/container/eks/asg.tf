locals {
  # https://docs.aws.amazon.com/eks/latest/userguide/retrieve-ami-id.html
  ami_ssm_name = {
    amazon-linux-2-x86_64 = "/aws/service/eks/optimized-ami/${var.eks.cluster_version}/amazon-linux-2/recommended/image_id"
    amazon-linux-2-arm64  = "/aws/service/eks/optimized-ami/${var.eks.cluster_version}/amazon-linux-2-arm64/recommended/image_id"
    amazon-linux-2-gpu    = "/aws/service/eks/optimized-ami/${var.eks.cluster_version}/amazon-linux-2-gpu/recommended/image_id"
    amazon-linux-2-inf    = "/aws/service/eks/optimized-ami/${var.eks.cluster_version}/amazon-linux-2-gpu/recommended/image_id" # gpu and inf same
  }
}

data "aws_ssm_parameter" "eks_optimized_ami_id" {
  # TODO: handle no ec2
  name = local.ami_ssm_name[join("-", ["amazon", var.eks.group.ec2.os, var.eks.group.ec2.os_version, var.eks.group.ec2.architecture])]
}

locals {
  image_id = data.aws_ssm_parameter.eks_optimized_ami_id.value
}

# #------------------------
# #     EC2 autoscaler
# #------------------------
# module "asg" {
#   source = "../asg"

#   for_each = {
#     for key, value in var.ec2 :
#     key => {
#       name              = "${var.name}-${key}"
#       capacity_provider = value.capacity_provider
#       use_spot          = value.use_spot
#       instance_market_options = value.use_spot ? {
#         # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template#market-options
#         market_type = "spot"
#         # spot_options = {
#         #   block_duration_minutes = 60
#         # }
#       } : {}
#       tag_specifications = value.use_spot ? [{
#         resource_type = "spot-instances-request"
#         tags          = merge(var.tags, { Name = "${var.name}-spot-instance-request" })
#       }] : []
#       instance_type    = value.instance_type
#       key_name         = value.key_name # to SSH into instance
#       instance_refresh = value.asg.instance_refresh
#     } if var.service.deployment_type == "ec2"
#   }

#   vpc = var.vpc

#   name              = each.value.name
#   capacity_provider = each.value.capacity_provider
#   instance_type     = each.value.instance_type
#   key_name          = each.value.key_name
#   instance_refresh  = each.value.instance_refresh
#   use_spot          = each.value.use_spot

#   image_id                 = local.image_ids[each.key]
#   user_data_base64         = base64encode(local.user_data[each.key])
#   weight_total             = sum([for key, value in var.ec2 : value.capacity_provider.weight])
#   port_mapping             = "dynamic"
#   layer7_to_layer4_mapping = local.layer7_to_layer4_mapping
#   traffics                 = local.traffics
#   target_group_arns        = module.elb.elb.target_group_arns
#   source_security_group_id = module.elb.elb_sg.security_group_id

#   min_count     = var.service.min_count
#   max_count     = var.service.max_count
#   desired_count = var.service.desired_count

#   tags = var.tags
# }

# resource "aws_autoscaling_attachment" "ecs" {
#   for_each = {
#     for key, _ in var.ec2 :
#     key => {}
#     if var.service.deployment_type == "ec2"
#   }
#   autoscaling_group_name = module.asg[each.key].asg.autoscaling_group_name
#   lb_target_group_arn    = element(module.elb.elb.target_group_arns, 0)
# }

# # group notification
# # resource "aws_autoscaling_notification" "webserver_asg_notifications" {
# #   group_names = [
# #     aws_autoscaling_group.webserver_asg.name,
# #   ]
# #   notifications = [
# #     "autoscaling:EC2_INSTANCE_LAUNCH",
# #     "autoscaling:EC2_INSTANCE_TERMINATE",
# #     "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
# #     "autoscaling:EC2_INSTANCE_TERMINATE_ERROR",
# #   ]
# #   topic_arn = aws_sns_topic.webserver_topic.arn
# # }
# # resource "aws_sns_topic" "webserver_topic" {
# #   name = "webserver_topic"
# # }
