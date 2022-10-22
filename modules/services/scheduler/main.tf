locals {
  asg_name = var.asg_name
}

resource "aws_autoscaling_schedule" "scale_out_in_morning" {
  scheduled_action_name  = "${var.cluster_name}-scale-out-morning"
  min_size              = 2
  max_size              = 10
  desired_capacity      = 10
  recurrence            = "0 9 * * *" # 9 a.m. everyday

  autoscaling_group_name = local.asg_name
}
resource "aws_autoscaling_schedule" "scale_in_at_night" {
  scheduled_action_name  = "${var.cluster_name}-scale-in-at-night"
  min_size              = 2
  max_size              = 10
  desired_capacity      = 2
  recurrence            = "0 17 * * *" # 5 p.m. everyday

  autoscaling_group_name = local.asg_name
}