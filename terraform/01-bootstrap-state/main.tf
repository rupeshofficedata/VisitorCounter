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

# The bucket every OTHER Terraform config in this project will store its
# state in. This bootstrap config itself intentionally does NOT use this
# bucket as its own backend - it uses local state, since it exists to create
# the very backend everything else depends on.
resource "aws_s3_bucket" "tfstate" {
  bucket = "visitorcounter-tfstate"

  # Deliberately never destroyed by a normal `terraform destroy` in the
  # directories that USE this bucket as their backend - only this bootstrap
  # config owns its lifecycle.
  lifecycle {
    prevent_destroy = true
  }
}

# Versioning on the state bucket: if state is ever corrupted or overwritten,
# a previous version can be restored - the state-file equivalent of a backup.
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

# The lock table Terraform's S3 backend uses to prevent two concurrent
# `apply` runs from corrupting state. "LockID" as the hash key name is not
# arbitrary - it's what Terraform's backend code specifically looks for.
resource "aws_dynamodb_table" "tfstate_lock" {
  name         = "visitorcounter-tfstate-lock"
  billing_mode = "PAY_PER_REQUEST" # no capacity planning needed for tiny, bursty lock traffic
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }
}
