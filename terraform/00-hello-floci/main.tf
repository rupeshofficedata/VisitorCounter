# Pins the AWS provider so `terraform init` always installs a known, tested
# version instead of silently picking up a new major release.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Points every AWS API call this config makes at floci (the local emulator)
# instead of real AWS. Every field here except `region` exists purely for
# that redirect - a real AWS config would just have `provider "aws" { region = ... }`.
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    s3       = "http://localhost.floci.io:4566"
    dynamodb = "http://localhost.floci.io:4566"
    iam      = "http://localhost.floci.io:4566"
    ec2      = "http://localhost.floci.io:4566"
    sts      = "http://localhost.floci.io:4566"
  }
}

# Minimal proof-of-connection resource - created and destroyed once just to
# confirm Terraform -> provider -> floci -> a real resource all actually works.
resource "aws_s3_bucket" "hello" {
  bucket = "visitorcounter-hello-floci"
}
