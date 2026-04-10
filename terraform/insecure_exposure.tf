# Intentionally insecure infrastructure to test NetGuard merge blocking.

resource "aws_security_group" "ssh_open_to_world" {
  name        = "demo-ssh-open-to-world"
  description = "SSH open to entire internet"
  vpc_id      = aws_vpc.primary.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 65535
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

resource "aws_security_group" "db_exposed_to_internet" {
  name        = "demo-db-exposed-internet"
  description = "Database ports exposed to the entire internet"
  vpc_id      = aws_vpc.primary.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
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

resource "aws_s3_bucket" "leaked_secrets" {
  bucket = "demo-guard-leaked-secrets-bucket"

  tags = {
    Name        = "leaked-secrets"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_public_access_block" "leaked_secrets" {
  bucket = aws_s3_bucket.leaked_secrets.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_instance" "admin_exposed" {
  ami                         = var.demo_ami
  instance_type               = "t3.large"
  subnet_id                   = aws_subnet.primary_public_a.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ssh_open_to_world.id]
  iam_instance_profile        = "production-admin-iam-profile"

  tags = {
    Name = "demo-admin-exposed-instance"
    Data = "sensitive-customer-pii"
  }
}

resource "aws_ebs_volume" "unencrypted_data" {
  availability_zone = "us-east-1a"
  size              = 100
  encrypted         = false

  tags = {
    Name = "demo-unencrypted-volume"
  }
}
