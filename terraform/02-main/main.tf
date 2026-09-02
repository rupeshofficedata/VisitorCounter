# Pins the AWS provider so `terraform init` always installs a known, tested
# version instead of silently picking up a new major release.
#
# The `backend "s3"` block is the actual Part 3 migration: instead of the
# default local terraform.tfstate file, state for THIS directory now lives
# in the bucket + lock table created by 01-bootstrap-state. Every teammate
# (or CI run) working on this directory shares the same state and the same
# lock, instead of each having their own private, unshared local file.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "visitorcounter-tfstate"
    key            = "main/terraform.tfstate" # path INSIDE the bucket - lets multiple projects share one bucket
    region         = "us-east-1"
    dynamodb_table = "visitorcounter-tfstate-lock"

    # Same floci redirect as every other config - the backend block
    # initializes separately from the provider block below, so it needs
    # its own copy of these settings.
    access_key                  = "test"
    secret_key                  = "test"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    use_path_style               = true

    endpoints = {
      s3       = "http://localhost.floci.io:4566"
      dynamodb = "http://localhost.floci.io:4566"
    }
  }
}

# Points every AWS API call this config makes at floci (the local emulator)
# instead of real AWS.
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

# First real piece of VisitorCounter's "infra": a dedicated VPC instead of
# using whatever default VPC an account happens to have. A real project's
# network boundary should be deliberately defined, not inherited by accident.
resource "aws_vpc" "visitorcounter" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "visitorcounter"
  }
}
