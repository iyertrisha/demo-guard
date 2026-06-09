# Extended breach patterns: exposed management ports (RDP/MSSQL) on internet-facing SG.
# Analogues: ransomware entry via exposed RDP (Colonial Pipeline class), public DB admin ports.
# Triggers NetGuard RDP_EXPOSED_TO_PUBLIC / MSSQL_EXPOSED_TO_PUBLIC style rules.
# Do not apply to a real AWS account.

resource "aws_security_group" "legacy_windows_admin" {
  name        = "demo-legacy-windows-admin-sg"
  description = "RDP and MSSQL exposed to the internet — common ransomware entry path"
  vpc_id      = aws_vpc.primary.id

  ingress {
    description = "RDP from anywhere"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "MSSQL from anywhere"
    from_port   = 1433
    to_port     = 1433
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
    Name      = "demo-legacy-windows-admin-sg"
    BreachRef = "exposed-rdp-mssql"
  }
}

resource "aws_instance" "legacy_windows_jump" {
  ami                         = var.demo_ami
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.primary_public_a.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.legacy_windows_admin.id]
  iam_instance_profile        = aws_iam_instance_profile.internet_admin_bastion_profile.name

  tags = {
    Name        = "demo-legacy-windows-jump"
    Environment = var.environment
    BreachRef   = "exposed-rdp-mssql"
    DataClass   = "customer-pii"
  }
}
