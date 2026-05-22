# Compound breach pattern: internet-facing EC2 + administrative IAM instance profile.
# NetGuard rule: INTERNET_EXPOSED_ADMIN_EC2 (CRITICAL).
# Real-world analogues: compromised public bastions / mis-scoped admin roles on edge hosts
# (e.g. Capital One WAF EC2 with ISRM-WAF-Role, public-reachable admin jump boxes).
# Do not apply to a real AWS account.

resource "aws_iam_role" "internet_admin_bastion_role" {
  name = "demo-internet-admin-bastion-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  inline_policy {
    name = "AdministratorAccess-equivalent"
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
    Name      = "demo-internet-admin-bastion-role"
    BreachRef = "internet-exposed-admin-ec2"
  }
}

resource "aws_iam_instance_profile" "internet_admin_bastion_profile" {
  name = "demo-internet-admin-ec2-profile"
  role = aws_iam_role.internet_admin_bastion_role.name

  tags = {
    BreachRef = "internet-exposed-admin-ec2"
  }
}

resource "aws_security_group" "internet_admin_bastion_sg" {
  name        = "demo-internet-admin-bastion-sg"
  description = "SSH and HTTPS open to the world on an admin-privileged bastion"
  vpc_id      = aws_vpc.primary.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
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

  tags = {
    Name      = "demo-internet-admin-bastion-sg"
    BreachRef = "internet-exposed-admin-ec2"
  }
}

resource "aws_instance" "internet_admin_bastion" {
  ami                         = var.demo_ami
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.primary_public_a.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.internet_admin_bastion_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.internet_admin_bastion_profile.name

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"
    http_put_response_hop_limit = 1
  }

  user_data = <<-EOF
    #!/bin/bash
    # Demo label: public admin bastion — immediate cloud account takeover if RCE/SSH compromised.
    echo "internet-admin-bastion" > /etc/hostname
  EOF

  tags = {
    Name        = "demo-internet-admin-bastion"
    Role        = "bastion"
    Environment = var.environment
    BreachRef   = "internet-exposed-admin-ec2"
    DataClass   = "customer-pii"
  }
}
