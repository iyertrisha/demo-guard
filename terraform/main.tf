# NetGuard demo — intentionally broken patterns. Do not apply to real AWS.
terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Unpinned remote module (supply-chain style signal in NetGuard parser)
module "external_stub" {
  source = "github.com/terraform-aws-modules/terraform-aws-vpc"
}

variable "demo_ami" {
  type    = string
  default = "ami-0c55b159cbfafe1f0"
}

variable "environment" {
  type    = string
  default = "demo-guard-flawed"
}

provider "aws" {
  region = "us-east-1"
}
