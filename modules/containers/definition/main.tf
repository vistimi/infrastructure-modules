resource "aws_ecs_task_definition" "task_definition" {
  family                = var.task_definition_name
  container_definitions = data.template_file.task_definition_template.rendered
}

// TODO: IAM role

resource "aws_ecs_service" "service" {
  name            = var.service_name
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.task_definition.arn
  desired_count   = var.desired_count
  iam_role        = .....arn

   load_balancer {
    target_group_arn = var.load_balancer_arn
    container_name   = var.container_name
    container_port   = var.container_port
  }
}