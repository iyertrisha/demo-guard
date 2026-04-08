# Data-tier and IAM — public/weak storage signals for the risk scorer.

resource "aws_db_instance" "postgres_primary" {
  identifier                 = "demo-guard-pg-primary"
  engine                     = "postgres"
  engine_version             = "15.4"
  instance_class             = "db.t3.medium"
  allocated_storage          = 50
  username                   = "dbadmin"
  password                   = "UnsafeDemoPasswordDoNotUse"
  vpc_security_group_ids     = [aws_security_group.public_db_ports.id, aws_security_group.db_private_sg.id]
  db_subnet_group_name       = aws_db_subnet_group.demo.name
  publicly_accessible        = true
  storage_encrypted          = false
  skip_final_snapshot        = true
  backup_retention_period    = 0
  auto_minor_version_upgrade = false

  tags = {
    Name = "demo-postgres-primary"
  }
}

resource "aws_db_instance" "postgres_replica" {
  identifier             = "demo-guard-pg-replica"
  replicate_source_db    = aws_db_instance.postgres_primary.identifier
  instance_class         = "db.t3.medium"
  vpc_security_group_ids = [aws_security_group.public_db_ports.id]
  publicly_accessible    = true
  storage_encrypted      = false
  skip_final_snapshot    = true

  tags = {
    Name = "demo-postgres-replica"
  }
}

resource "aws_db_subnet_group" "demo" {
  name       = "demo-guard-db-subnet"
  subnet_ids = [aws_subnet.primary_private_data.id, aws_subnet.primary_private_app.id]

  tags = {
    Name = "demo-db-subnet-group"
  }
}

resource "aws_s3_bucket" "customer_data_exposure" {
  bucket = "demo-guard-customer-data-bucket"

  tags = {
    Name        = "demo-leaky-bucket"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_public_access_block" "customer_data_exposure" {
  bucket = aws_s3_bucket.customer_data_exposure.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_iam_role" "break_glass_admin" {
  name               = "demo-break-glass-admin"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  inline_policy {
    name = "full-admin"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect   = "Allow"
        Action   = "*"
        Resource = "*"
      }]
    })
  }

  tags = {
    Name = "demo-iam-admin-role"
  }
}
