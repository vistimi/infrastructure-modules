#------------------------
#     IP
#------------------------
resource "random_shuffle" "az" {
  input        = local.subnets
  result_count = 1
}

data "aws_subnet" "selected" {
  id = random_shuffle.az.result[0]
}

locals {
  cidr_prefix  = split("/", data.aws_subnet.selected.cidr_block)[1]
  host_numbers = range(pow(2, 32 - local.cidr_prefix))
}

resource "random_shuffle" "cidr" {
  input        = local.host_numbers
  result_count = length(var.ec2)
}

locals {
  selected_ips = { for key, value in var.ec2 : key => random_shuffle.az.result[index(keys(var.ec2), key)] }
}


// diff

resource "random_shuffle" "az" {
  input        = local.subnets
  result_count = 1
}

data "aws_subnet" "selected" {
  id = random_shuffle.az.result[0]
}

locals {
  cidr_prefix  = split("/", data.aws_subnet.selected.cidr_block)[1]
  host_numbers = pow(2, 32 - local.cidr_prefix)
}

# resource "random_shuffle" "cidr" {
#   input        = local.host_numbers
#   result_count = length(var.ec2)
# }

resource "random_integer" "cidr" {
  for_each = {
    for key, value in var.ec2 :
    key => {}
    if !var.service.use_fargate
  }

  min = 1
  max = local.host_numbers
}

locals {
  selected_ips = { for key, value in var.ec2 : key => cidrhost(data.aws_subnet.selected.cidr_block, random_integer.cidr[key].result) }
}

resource "aws_eip" "single" {
  for_each = {
    for key, value in var.ec2 :
    key => {}
    if !var.service.use_fargate
  }

  domain = "vpc"
  # network_interface         = aws_network_interface.multi-ip.id
  associate_with_private_ip = local.selected_ips[each.key]

  tags = var.common_tags
}
