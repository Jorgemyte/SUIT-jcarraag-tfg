resource "aws_vpc" "vpc" {
  cidr_block = var.cidr_block

  tags = {
    Name = "${var.project_name}-vpc-${var.environment}"
    Environment = var.environment
  }
}

data "aws_availability_zone" "available" {}

resource "aws_subnet" "public_subnet" {
  count = 3
  vpc_id = aws_vpc.vpc.id
  cidr_block = cidrsubnet(aws_vpc.vpc.cidr_block,8,count.index)
  availability_zone = data.aws_availability_zone.available[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index+1}-${var.environment}"
    Environment = var.environment
  }
}

