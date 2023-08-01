data "aws_ssm_parameter" "ecs_optimized_ami_id" {

  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/gpu/recommended/image_id"
}

output "ssm" {
  value = data.aws_ssm_parameter.ecs_optimized_ami_id
}
