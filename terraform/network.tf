# Blast-radius focused topology:
# keep a small but multi-hop graph so hop depth changes are visible.

resource "aws_vpc" "primary" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name        = "demo-primary-vpc"
    Environment = var.environment
  }
}

resource "aws_subnet" "primary_public_a" {
  vpc_id                  = aws_vpc.primary.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags                    = { Name = "demo-primary-public-a" }
}

resource "aws_subnet" "primary_private_app" {
  vpc_id     = aws_vpc.primary.id
  cidr_block = "10.0.10.0/24"
  tags       = { Name = "demo-primary-private-app" }
}

resource "aws_subnet" "primary_private_data" {
  vpc_id     = aws_vpc.primary.id
  cidr_block = "10.0.20.0/24"
  tags       = { Name = "demo-primary-private-data" }
}

resource "aws_internet_gateway" "primary_igw" {
  vpc_id = aws_vpc.primary.id
  tags   = { Name = "demo-primary-igw" }
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "demo-nat-eip" }
}

resource "aws_nat_gateway" "primary_nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.primary_public_a.id
  tags          = { Name = "demo-primary-nat" }
}

# --- Security groups (intentionally overexposed) ---

resource "aws_security_group" "public_web_http_only" {
  name        = "demo-public-web-http-only"
  description = "HTTP 80 open to world without HTTPS — triggers HTTP_WITHOUT_HTTPS style risk"
  vpc_id      = aws_vpc.primary.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "internal_app" {
  name        = "demo-internal-app"
  description = "Application tier — still attached to public-tier instances for demo chaining"
  vpc_id      = aws_vpc.primary.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db_private_sg" {
  name        = "demo-db-private-sg"
  description = "DB tier in private subnet"
  vpc_id      = aws_vpc.primary.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
