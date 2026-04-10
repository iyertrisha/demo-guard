# Smaller compute graph for clearer hop-depth blast-radius testing.

resource "aws_instance" "web_tier_a" {
  ami                         = var.demo_ami
  instance_type               = "t3.small"
  subnet_id                   = aws_subnet.primary_public_a.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.public_web_http_only.id]
  iam_instance_profile        = "demo-web-low-priv-profile"
  tags = {
    Name        = "demo-web-a"
    Role        = "web"
    Environment = var.environment
  }
}

resource "aws_instance" "app_worker_1" {
  ami                    = var.demo_ami
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.primary_private_app.id
  vpc_security_group_ids = [aws_security_group.internal_app.id]
  iam_instance_profile   = "production-admin-iam-profile"
  tags = {
    Name = "demo-app-worker-1"
    Data = "sensitive-customer-pii"
  }
}

resource "aws_instance" "db_jumpbox" {
  ami                    = var.demo_ami
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.primary_private_data.id
  vpc_security_group_ids = [aws_security_group.db_private_sg.id]
  tags = {
    Name = "demo-db-jumpbox"
  }
}

resource "aws_lb" "public_app_alb" {
  name               = "demo-public-alb"
  load_balancer_type = "application"
  internal           = false
  subnets            = [aws_subnet.primary_public_a.id]
  security_groups    = [aws_security_group.public_web_http_only.id]

  tags = {
    Name = "demo-public-alb"
  }
}
