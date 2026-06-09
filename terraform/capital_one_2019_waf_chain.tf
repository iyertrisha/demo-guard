# Educational demo only — patterns from the 2019 Capital One breach (106M records).
# Root cause chain (public reporting): misconfigured ModSecurity WAF reverse proxy on EC2
# → SSRF to Instance Metadata (IMDSv1) → stolen ISRM-WAF-Role credentials →
# s3:ListBucket / s3:GetObject across customer S3 buckets (aws s3 ls / aws s3 sync).
# Do not apply to a real AWS account.

resource "aws_iam_role" "isrm_waf_role" {
  name = "demo-isrm-waf-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = "demo-isrm-waf-role"
    Environment = var.environment
    BreachRef   = "capital-one-2019-waf-role"
  }
}

# Over-privileged WAF role: list/read customer buckets (least-privilege violation).
resource "aws_iam_role_policy" "isrm_waf_s3_exfiltration" {
  name = "demo-isrm-waf-s3-read"
  role = aws_iam_role.isrm_waf_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListAllBucketsLikeCapitalOneIndictment"
        Effect = "Allow"
        Action = [
          "s3:ListAllMyBuckets",
          "s3:ListBucket",
        ]
        Resource = "*"
      },
      {
        Sid    = "ReadCustomerDataBuckets"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
        ]
        Resource = [
          "${aws_s3_bucket.customer_data_exposure.arn}/*",
          "arn:aws:s3:::demo-guard-*/*",
        ]
      },
    ]
  })
}

resource "aws_iam_instance_profile" "isrm_waf_profile" {
  name = "demo-isrm-waf-instance-profile"
  role = aws_iam_role.isrm_waf_role.name

  tags = {
    BreachRef = "capital-one-2019-ec2-profile"
  }
}

resource "aws_security_group" "waf_reverse_proxy" {
  name        = "demo-waf-reverse-proxy-sg"
  description = "ModSecurity-style WAF on EC2 — wide egress enables SSRF to 169.254.169.254 (IMDS)"
  vpc_id      = aws_vpc.primary.id

  ingress {
    description = "Public HTTP to WAF reverse proxy"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Public HTTPS to WAF reverse proxy"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Unrestricted egress — SSRF can reach metadata service and external endpoints"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "demo-waf-reverse-proxy-sg"
    BreachRef = "capital-one-2019-ssrf-egress"
  }
}

resource "aws_instance" "waf_reverse_proxy" {
  ami                         = var.demo_ami
  instance_type               = "t3.small"
  subnet_id                   = aws_subnet.primary_public_a.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.waf_reverse_proxy.id]
  iam_instance_profile        = aws_iam_instance_profile.isrm_waf_profile.name

  # IMDSv1 left enabled (http_tokens optional) — Capital One era metadata theft via SSRF.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  user_data = <<-EOF
    #!/bin/bash
    # Demo label only: open-source WAF reverse proxy (ModSecurity) misconfiguration class.
    # Attackers abused Host-header / proxy forwarding to query:
    # http://169.254.169.254/latest/meta-data/iam/security-credentials/demo-isrm-waf-role
    yum -y install httpd mod_security
    systemctl enable httpd
    systemctl start httpd
  EOF

  tags = {
    Name        = "demo-waf-modsecurity-proxy"
    Role        = "waf"
    Environment = var.environment
    BreachRef   = "capital-one-2019-waf-ec2"
    DataClass   = "customer-pii-credit-applications"
  }
}
