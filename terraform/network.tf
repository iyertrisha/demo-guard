# Two VPCs and several subnets to multiply graph nodes (vpc → subnet → ec2 edges).

resource "aws_vpc" "primary" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name        = "demo-primary-vpc"
    Environment = var.environment
  }
}

resource "aws_vpc" "secondary" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name        = "demo-secondary-vpc"
    Environment = var.environment
  }
}

resource "aws_subnet" "primary_public_a" {
  vpc_id                  = aws_vpc.primary.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags                    = { Name = "demo-primary-public-a" }
}

resource "aws_subnet" "primary_public_b" {
  vpc_id                  = aws_vpc.primary.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  tags                    = { Name = "demo-primary-public-b" }
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

resource "aws_subnet" "secondary_app" {
  vpc_id     = aws_vpc.secondary.id
  cidr_block = "10.1.1.0/24"
  tags       = { Name = "demo-secondary-app" }
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

resource "aws_security_group" "public_ssh" {
  name        = "demo-public-ssh"
  description = "SSH from anywhere"
  vpc_id      = aws_vpc.primary.id

  ingress {
    from_port   = 22
    to_port     = 22
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

resource "aws_security_group" "public_rdp" {
  name        = "demo-public-rdp"
  description = "RDP from anywhere"
  vpc_id      = aws_vpc.primary.id

  ingress {
    from_port   = 3389
    to_port     = 3389
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

resource "aws_security_group" "public_db_ports" {
  name        = "demo-public-database-ports"
  description = "Multiple DB protocols exposed to the internet"
  vpc_id      = aws_vpc.primary.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 27017
    to_port     = 27017
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

resource "aws_security_group" "wide_open_internet" {
  name        = "demo-wide-open"
  description = "All traffic from internet — ALL_PORTS / blast-surface"
  vpc_id      = aws_vpc.primary.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
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

resource "aws_security_group" "shared_worker_sg" {
  name        = "demo-shared-worker"
  description = "Shared by several instances — lateral movement / blast radius demo"
  vpc_id      = aws_vpc.primary.id

  ingress {
    from_port   = 0
    to_port     = 65535
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
