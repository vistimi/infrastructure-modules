data "aws_vpc" "current" {
  id = "vpc-013a411b59dd8a08e"
}

output "test" {
  value = data.aws_vpc.current
}
