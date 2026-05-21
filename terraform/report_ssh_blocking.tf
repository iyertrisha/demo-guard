# Mini-project report §9.1 — deliberate CRITICAL demo pattern (screenshots only).
# DO NOT apply this Terraform to a real AWS account.
#
# NetGuard typically surfaces SSH_EXPOSED_TO_PUBLIC when port 22 is open to 0.0.0.0/0.

resource "aws_security_group" "report_ssh_world" {
  name        = "demo-report-ssh-world"
  description = "Report demo: SSH from Internet — triggers SSH_EXPOSED_TO_PUBLIC"
  vpc_id      = aws_vpc.primary.id

  ingress {
    description = "Report demo — world SSH (CRITICAL finding)"
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

  tags = {
    Name       = "demo-report-ssh-world"
    ReportDemo = "section-9.1"
  }
}
