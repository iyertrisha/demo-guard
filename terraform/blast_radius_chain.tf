# Multi-hop blast radius demo.
#
# Topology (designed for clear hop-depth visibility):
#
#   internet
#     |
#   dmz_sg  (SSH open to 0.0.0.0/0 -- CRITICAL)
#     |
#   bastion  (public subnet, public IP)
#     |
#   app_sg  (port 8080 from bastion SG)
#     |
#   app_server  (private subnet)
#     |
#   cache_sg  (port 6379 from app SG)
#     |
#   redis_cache  (private subnet)
#     |
#   data_sg  (port 5432 from cache SG)
#     |
#   database  (private data subnet, unencrypted)
#     |
#   backup_bucket  (public S3 -- CRITICAL)
#
# This creates a 5+ hop chain so each blast radius depth reveals new nodes.

# ─── Isolated VPC for this chain ────────────────────────────────────────────

resource "aws_vpc" "chain_vpc" {
  cidr_block           = "10.100.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "chain-demo-vpc" }
}

resource "aws_subnet" "chain_public" {
  vpc_id                  = aws_vpc.chain_vpc.id
  cidr_block              = "10.100.1.0/24"
  map_public_ip_on_launch = true
  tags = { Name = "chain-public-subnet" }
}

resource "aws_subnet" "chain_app" {
  vpc_id     = aws_vpc.chain_vpc.id
  cidr_block = "10.100.10.0/24"
  tags = { Name = "chain-app-subnet" }
}

resource "aws_subnet" "chain_cache" {
  vpc_id     = aws_vpc.chain_vpc.id
  cidr_block = "10.100.20.0/24"
  tags = { Name = "chain-cache-subnet" }
}

resource "aws_subnet" "chain_data" {
  vpc_id     = aws_vpc.chain_vpc.id
  cidr_block = "10.100.30.0/24"
  tags = { Name = "chain-data-subnet" }
}

# ─── Security groups (each scoped to ONE next hop) ─────────────────────────

resource "aws_security_group" "chain_dmz" {
  name        = "chain-dmz-sg"
  description = "SSH open to internet -- CRITICAL finding"
  vpc_id      = aws_vpc.chain_vpc.id

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
    cidr_blocks = ["10.100.10.0/24"]
  }
}

resource "aws_security_group" "chain_app_sg" {
  name        = "chain-app-sg"
  description = "App tier -- accepts traffic from DMZ only"
  vpc_id      = aws_vpc.chain_vpc.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["10.100.1.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.100.20.0/24"]
  }
}

resource "aws_security_group" "chain_cache_sg" {
  name        = "chain-cache-sg"
  description = "Cache tier -- accepts traffic from app only"
  vpc_id      = aws_vpc.chain_vpc.id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["10.100.10.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.100.30.0/24"]
  }
}

resource "aws_security_group" "chain_data_sg" {
  name        = "chain-data-sg"
  description = "Data tier -- accepts traffic from cache only"
  vpc_id      = aws_vpc.chain_vpc.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.100.20.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ─── Compute chain ─────────────────────────────────────────────────────────

resource "aws_instance" "chain_bastion" {
  ami                         = var.demo_ami
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.chain_public.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.chain_dmz.id]
  tags = { Name = "chain-bastion" }
}

resource "aws_instance" "chain_app" {
  ami                    = var.demo_ami
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.chain_app.id
  vpc_security_group_ids = [aws_security_group.chain_app_sg.id]
  tags = { Name = "chain-app-server" }
}

resource "aws_instance" "chain_cache" {
  ami                    = var.demo_ami
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.chain_cache.id
  vpc_security_group_ids = [aws_security_group.chain_cache_sg.id]
  tags = { Name = "chain-redis-cache" }
}

resource "aws_db_instance" "chain_db" {
  identifier             = "chain-demo-db"
  engine                 = "postgres"
  engine_version         = "15.4"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  username               = "admin"
  password               = "ChainDemoPassword"
  vpc_security_group_ids = [aws_security_group.chain_data_sg.id]
  publicly_accessible    = false
  storage_encrypted      = false
  skip_final_snapshot    = true

  tags = { Name = "chain-database" }
}

# ─── End of chain: public backup bucket ────────────────────────────────────

resource "aws_s3_bucket" "chain_backup" {
  bucket = "chain-demo-backup-bucket"
  tags   = { Name = "chain-backup-public" }
}

resource "aws_s3_bucket_public_access_block" "chain_backup" {
  bucket = aws_s3_bucket.chain_backup.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
