resource "aws_vpc" "vpc" {
  cidr_block           = "${var.networkcidr}.0.0/16"
  tags                 = { "Name" = "${var.projectname}" }
  enable_dns_hostnames = true
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "${var.networkcidr}.1.0/24"
  availability_zone       = "${var.awsregion}a"
  map_public_ip_on_launch = true
  tags                    = { "Name" = "${var.projectname}-public-subnet-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "${var.networkcidr}.2.0/24"
  availability_zone = "${var.awsregion}b"
  tags              = { "Name" = "${var.projectname}-public-subnet-b" }
}

resource "aws_subnet" "public_c" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "${var.networkcidr}.3.0/24"
  availability_zone = "${var.awsregion}c"
  tags              = { "Name" = "${var.projectname}-public-subnet-c" }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "${var.networkcidr}.4.0/24"
  availability_zone = "${var.awsregion}a"
  tags              = { "Name" = "${var.projectname}-private-subnet-a" }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "${var.networkcidr}.5.0/24"
  availability_zone = "${var.awsregion}b"
  tags              = { "Name" = "${var.projectname}-private-subnet-b" }
}

resource "aws_subnet" "private_c" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "${var.networkcidr}.6.0/24"
  availability_zone = "${var.awsregion}c"
  tags              = { "Name" = "${var.projectname}-private-subnet-c" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id
  tags   = { "Name" = "${var.projectname}-private-route-table" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id
  tags   = { "Name" = "${var.projectname}-public-route-table" }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_c" {
  subnet_id      = aws_subnet.public_c.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_a_subnet" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b_subnet" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_c_subnet" {
  subnet_id      = aws_subnet.private_c.id
  route_table_id = aws_route_table.private.id
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags   = { "Name" = "${var.projectname}-igw" }
}

resource "aws_eip" "nat" {
  domain = "vpc"
  # vpc = true
  tags = { "Name" = "${var.projectname}-ngw-eip" }
}

resource "aws_nat_gateway" "ngw" {
  subnet_id     = aws_subnet.public_a.id
  allocation_id = aws_eip.nat.id
  depends_on    = [aws_internet_gateway.igw]
  tags          = { "Name" = "${var.projectname}-ngw" }
}

resource "aws_route" "public_igw" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route" "private_ngw" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.ngw.id
}
