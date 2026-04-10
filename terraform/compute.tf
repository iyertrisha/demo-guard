# Many EC2 instances across subnets × security groups → large graph + blast radius metadata.

locals {
  web_tier_sgs = [
    aws_security_group.public_web_http_only.id,
    aws_security_group.internal_app.id,
  ]
  bastion_sgs = [
    aws_security_group.public_ssh.id,
    aws_security_group.shared_worker_sg.id,
  ]
}

resource "aws_instance" "web_tier_a" {
  ami                         = var.demo_ami
  instance_type               = "t3.small"
  subnet_id                   = aws_subnet.primary_public_a.id
  associate_public_ip_address = true
  vpc_security_group_ids      = local.web_tier_sgs
  iam_instance_profile        = "demo-web-low-priv-profile"
  tags = {
    Name        = "demo-web-a"
    Role        = "web"
    Environment = var.environment
  }
}

resource "aws_instance" "web_tier_b" {
  ami                         = var.demo_ami
  instance_type               = "t3.small"
  subnet_id                   = aws_subnet.primary_public_b.id
  associate_public_ip_address = true
  vpc_security_group_ids      = local.web_tier_sgs
  tags = {
    Name        = "demo-web-b"
    Role        = "web"
    Environment = var.environment
  }
}

resource "aws_instance" "jump_host" {
  ami                         = var.demo_ami
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.primary_public_a.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.public_ssh.id]
  tags = {
    Name = "demo-jump-host"
  }
}

resource "aws_instance" "windows_debug" {
  ami                         = var.demo_ami
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.primary_public_b.id
  vpc_security_group_ids      = [aws_security_group.public_rdp.id, aws_security_group.shared_worker_sg.id]
  tags = {
    Name = "demo-windows-rdp"
  }
}

resource "aws_instance" "app_worker_1" {
  ami                    = var.demo_ami
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.primary_private_app.id
  vpc_security_group_ids = [aws_security_group.internal_app.id, aws_security_group.shared_worker_sg.id]
  iam_instance_profile   = "production-admin-iam-profile"
  tags = {
    Name = "demo-app-worker-1"
    Data = "sensitive-customer-pii"
  }
}

resource "aws_instance" "app_worker_2" {
  ami                    = var.demo_ami
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.primary_private_app.id
  vpc_security_group_ids = [aws_security_group.internal_app.id, aws_security_group.shared_worker_sg.id]
  tags = {
    Name = "demo-app-worker-2"
  }
}

resource "aws_instance" "db_jumpbox" {
  ami                    = var.demo_ami
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.primary_private_data.id
  vpc_security_group_ids = [aws_security_group.public_db_ports.id, aws_security_group.db_private_sg.id]
  tags = {
    Name = "demo-db-jumpbox"
  }
}

resource "aws_instance" "wide_open_host" {
  ami                         = var.demo_ami
  instance_type               = "t3.large"
  subnet_id                   = aws_subnet.primary_public_a.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.wide_open_internet.id]
  iam_instance_profile        = "production-admin-iam-profile"
  tags = {
    Name = "demo-wide-open-host"
  }
}

resource "aws_instance" "secondary_vpc_worker" {
  ami                    = var.demo_ami
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.secondary_app.id
  vpc_security_group_ids = [aws_security_group.public_ssh.id]
  tags = {
    Name = "demo-secondary-worker"
  }
}

resource "aws_lb" "public_app_alb" {
  name               = "demo-public-alb"
  load_balancer_type = "application"
  internal           = false
  subnets            = [aws_subnet.primary_public_a.id, aws_subnet.primary_public_b.id]
  security_groups    = [aws_security_group.public_web_http_only.id, aws_security_group.wide_open_internet.id]

  tags = {
    Name = "demo-public-alb"
  }
}

# Test: unencrypted EBS volume for NetGuard scan verification
resource "aws_ebs_volume" "unencrypted_test" {
  availability_zone = "us-east-1a"
  size              = 20
  encrypted         = false

  tags = {
    Name = "netguard-scan-test"
  }
}
