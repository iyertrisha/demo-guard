# Twilio / hard-coded cloud credential leaks in IaC (2022 reporting pattern).
# Secrets embedded in Terraform user_data instead of Secrets Manager / SSM.
# Do not apply to a real AWS account.

resource "aws_instance" "ci_runner_with_embedded_secrets" {
  ami                         = var.demo_ami
  instance_type               = "t3.small"
  subnet_id                   = aws_subnet.primary_private_app.id
  vpc_security_group_ids      = [aws_security_group.internal_app.id]

  user_data = <<-EOF
    #!/bin/bash
    # DEMO ONLY — anti-pattern from credential-leak post-mortems
    export AWS_ACCESS_KEY_ID="AKIADEMO_EMBEDDED_IN_USERDATA"
    export AWS_SECRET_ACCESS_KEY="wJalrDEMOEmbeddedSecretInTerraformUserData"
    export DATABASE_URL="postgresql://admin:PlainTextDbPassword@demo-guard-pg-primary:5432/customers"
    curl -H "Authorization: Bearer ghp_DEMO_PAT_IN_USERDATA" https://api.github.com/user
  EOF

  tags = {
    Name      = "demo-ci-runner-embedded-secrets"
    BreachRef = "twilio-hardcoded-credentials-iac"
  }
}

resource "aws_lambda_function" "webhook_with_plain_env" {
  function_name = "demo-webhook-plain-env-secrets"
  role          = aws_iam_role.break_glass_admin.arn
  handler       = "index.handler"
  runtime       = "python3.12"

  environment {
    variables = {
      STRIPE_SECRET_KEY = "sk_live_DEMO_REPLACE_IN_CI_NOT_REAL"
      GITHUB_TOKEN      = "github_pat_DEMO_PLAIN_ENV_NOT_REAL"
      JWT_SIGNING_KEY   = "super-secret-jwt-key-in-lambda-env"
    }
  }

  filename         = "${path.module}/../scripts/post_pr_findings.py"
  source_code_hash = filebase64sha256("${path.module}/../scripts/post_pr_findings.py")

  tags = {
    BreachRef = "lambda-plaintext-env-secrets"
  }
}
