terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

# ================= VPC =================
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "${var.project_name}-VPC" }
}

# ================= Subnets =================
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block               = "10.0.1.0/24"
  availability_zone        = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch  = true
  tags = { Name = "Public-Subnet" }
}

resource "aws_subnet" "public2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block               = "10.0.4.0/24"
  availability_zone        = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch  = true
  tags = { Name = "Public-Subnet-2" }
}

resource "aws_subnet" "private_app" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = { Name = "Private-App-Subnet" }
}

resource "aws_subnet" "private_db" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = { Name = "Private-DB-Subnet" }
}

resource "aws_subnet" "private_db2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = { Name = "Private-DB-Subnet-2" }
}

# ================= Internet Gateway + Routing =================
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-IGW" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "Public-RT" }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_a2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public_rt.id
}

# ================= NAT Gateway (so private EC2 instances get internet access) =================
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.project_name}-NAT-EIP" }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  tags          = { Name = "${var.project_name}-NAT" }
  depends_on    = [aws_internet_gateway.igw]
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
  tags = { Name = "Private-RT" }
}

resource "aws_route_table_association" "private_app_a" {
  subnet_id      = aws_subnet.private_app.id
  route_table_id = aws_route_table.private_rt.id
}

# ================= Security Groups =================
resource "aws_security_group" "alb_sg" {
  name   = "ALB-SG"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ALB-SG" }
}

resource "aws_security_group" "ec2_sg" {
  name   = "EC2-SG"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "EC2-SG" }
}

resource "aws_security_group" "rds_sg" {
  name   = "RDS-SG"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "RDS-SG" }
}
