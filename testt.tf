data "aws_vpc" "current" {
  id = "vpc-0e1e39d24e51100b1"
}
output "microservice" {
  value = data.aws_vpc.current
}
