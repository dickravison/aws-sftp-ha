#Get AZ names based on number of AZs configured
locals {
  az_names = slice(data.aws_availability_zones.available.names, 0, var.azs)
  cidr_range = {
    latest = "10.1.0.0/16"
    test   = "10.2.0.0/16"
    beta   = "10.3.0.0/16"
    prod   = "10.4.0.0/16"
  }
  public_range = {
    latest = "10.1.1.0/20"
    test   = "10.2.1.0/20"
    beta   = "10.3.1.0/20"
    prod   = "10.4.1.0/20"
  }
  private_range = {
    latest = "10.1.16.0/20"
    test   = "10.2.16.0/20"
    beta   = "10.3.16.0/20"
    prod   = "10.4.16.0/20"
  }
}

#Main VPC
resource "aws_vpc" "main" {
  cidr_block           = lookup(local.cidr_range, var.Stage)
  enable_dns_support   = true
  enable_dns_hostnames = true
}

#Create public subnets
resource "aws_subnet" "public" {
  count             = length(local.az_names)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(lookup(local.public_range, var.Stage), 4, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
}

#Create private subnets
resource "aws_subnet" "private" {
  count             = length(local.az_names)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(lookup(local.private_range, var.Stage), 4, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
}

#Create IGW
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

#Create EIP for NAT GWs
resource "aws_eip" "nat" {
  count = length(local.az_names)
  vpc   = true
}

#Create NAT GW in public subnet, in each AZ and attach EIP
resource "aws_nat_gateway" "nat_gw" {
  count         = length(local.az_names)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
}

#Private subnets route table
resource "aws_route_table" "private" {
  count  = var.azs
  vpc_id = aws_vpc.main.id
}

#Public subnets route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
}

#Create route for each private subnet and set default route to NAT GW
resource "aws_route" "private_route" {
  count                  = var.azs
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw[count.index].id
}

#Create routes for each public subnet and set default route to IGW
resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

#Associate private subnet route tables with private subnets
resource "aws_route_table_association" "private" {
  count          = var.azs
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

#Associate public subnet route tables with public subnets
resource "aws_route_table_association" "public" {
  count          = var.azs
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
