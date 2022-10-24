locals {
  any_port       = 0
  any_protocol   = "-1"
  all_cidrs_ipv4 = "0.0.0.0/0"
  all_cidrs_ipv6 = "::/0"

  name               = "${var.project_name}-${var.environment_name}"
  cidrs_ipv4         = cidrsubnets(var.vpc_cidr_ipv4, 4, 4, 4, 4, 4, 4)
  public_cidrs_ipv4  = slice(local.cidrs_ipv4, 0, 3)
  private_cidrs_ipv4 = slice(local.cidrs_ipv4, 3, 6)
}

provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "vpc" {
  cidr_block                       = var.vpc_cidr_ipv4
  enable_dns_support               = true
  enable_dns_hostnames             = true
  assign_generated_ipv6_cidr_block = true
  tags                             = merge(var.common_tags, { Name = "${local.name}-vpc" })

  lifecycle {
    create_before_destroy = true
  }
}

# Internet GateWay for the public subnets
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
  tags   = merge(var.common_tags, { Name = "${local.name}-igw" })
}

# Public subnets
resource "aws_subnet" "public_subnet" {
  count             = length(local.public_cidrs_ipv4)
  vpc_id            = aws_vpc.vpc.id
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags              = merge(var.common_tags, { Name = "${local.name}-public-subnet-${element(data.aws_availability_zones.available.names, count.index)}" })

  # ipv4
  cidr_block              = element(local.public_cidrs_ipv4, count.index)
  map_public_ip_on_launch = true
  # ipv6
  assign_ipv6_address_on_creation = true
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.vpc.ipv6_cidr_block, 8, count.index)
}

# Private subnets
resource "aws_subnet" "private_subnet" {
  count             = length(local.private_cidrs_ipv4)
  vpc_id            = aws_vpc.vpc.id
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags              = merge(var.common_tags, { Name = "${local.name}-private-subnet-${element(data.aws_availability_zones.available.names, count.index)}" })

  # ipv4
  cidr_block              = element(local.private_cidrs_ipv4, count.index)
  map_public_ip_on_launch = true
}

# Routing table for public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id
  tags   = merge(var.common_tags, { Name = "${local.name}-public-route-table" })
}

resource "aws_route" "public_internet_gateway_ipv4" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = local.all_cidrs_ipv4
  gateway_id             = aws_internet_gateway.internet_gateway.id
}

resource "aws_route" "public_internet_gateway_ipv6" {
  route_table_id              = aws_route_table.public.id
  destination_ipv6_cidr_block = local.all_cidrs_ipv6
  gateway_id                  = aws_internet_gateway.internet_gateway.id
}

# Routing table for private subnets
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id
  tags   = merge(var.common_tags, { Name = "${local.name}-private-route-table" })
}

# Route table associations
resource "aws_route_table_association" "public" {
  count          = length(local.public_cidrs_ipv4)
  subnet_id      = element(aws_subnet.public_subnet.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(local.private_cidrs_ipv4)
  subnet_id      = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.private.id
}

# Security Group VPC
resource "aws_security_group" "vpc" {
  name        = "${local.name}-vpc-sg"
  description = "Default security group to allow inbound/outbound from the VPC"
  vpc_id      = aws_vpc.vpc.id
  depends_on  = [aws_vpc.vpc]
  tags        = merge(var.common_tags, { Name = "${local.name}-vpc-sg" })
}

resource "aws_security_group_rule" "allow_all_inbound_ipv4" {
  type              = "ingress"
  security_group_id = aws_security_group.vpc.id

  from_port   = local.any_port
  to_port     = local.any_port
  protocol    = local.any_protocol
  cidr_blocks = [local.all_cidrs_ipv4]
}

resource "aws_security_group_rule" "allow_all_outbound_ipv4" {
  type              = "egress"
  security_group_id = aws_security_group.vpc.id

  from_port   = local.any_port
  to_port     = local.any_port
  protocol    = local.any_protocol
  cidr_blocks = [local.all_cidrs_ipv4]
}

resource "aws_security_group_rule" "allow_all_inbound_ipv6" {
  type              = "ingress"
  security_group_id = aws_security_group.vpc.id

  from_port        = local.any_port
  to_port          = local.any_port
  protocol         = local.any_protocol
  ipv6_cidr_blocks = [local.all_cidrs_ipv6]
}

resource "aws_security_group_rule" "allow_all_outbound_ipv6" {
  type              = "egress"
  security_group_id = aws_security_group.vpc.id

  from_port        = local.any_port
  to_port          = local.any_port
  protocol         = local.any_protocol
  ipv6_cidr_blocks = [local.all_cidrs_ipv6]
}
