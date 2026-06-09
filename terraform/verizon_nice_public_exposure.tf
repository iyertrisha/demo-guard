# Verizon / NICE Systems (2017, ~14M records) — misconfigured public cloud storage exposure pattern.
# Customer call recordings and PII were left accessible due to weak S3-style ACL/policy controls.
# Reinforces NetGuard PUBLIC_S3_BUCKET on top of data.tf public access block settings.
# Do not apply to a real AWS account.

resource "aws_s3_bucket_policy" "customer_data_public_read" {
  bucket = aws_s3_bucket.customer_data_exposure.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadCustomerRecordings"
        Effect    = "Allow"
        Principal = "*"
        Action    = [
          "s3:GetObject",
          "s3:ListBucket",
        ]
        Resource = [
          aws_s3_bucket.customer_data_exposure.arn,
          "${aws_s3_bucket.customer_data_exposure.arn}/*",
        ]
      },
    ]
  })
}

resource "aws_s3_bucket_acl" "customer_data_public_acl" {
  bucket = aws_s3_bucket.customer_data_exposure.id
  acl    = "public-read"

  depends_on = [aws_s3_bucket_public_access_block.customer_data_exposure]
}
