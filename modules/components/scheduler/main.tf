resource "aws_autoscaling_schedule" "scale_out_in_morning" {
  scheduled_action_name  = "${var.cluster_name}-scale-out-morning"
  min_size              = var.min_size
  max_size              = var.max_size
  desired_capacity      = var.max_size
  recurrence            = "0 9 * * *" # 9 a.m. everyday

  autoscaling_group_name = var.asg_name
}
resource "aws_autoscaling_schedule" "scale_in_at_night" {
  scheduled_action_name  = "${var.cluster_name}-scale-in-at-night"
  min_size              = var.min_size
  max_size              = var.max_size
  desired_capacity      = var.min_size
  recurrence            = "0 17 * * *" # 5 p.m. everyday

  autoscaling_group_name = var.asg_name
}