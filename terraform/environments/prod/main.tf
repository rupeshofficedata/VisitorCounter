# Pins the AWS provider so `terraform init` always installs a known, tested
# version instead of silently picking up a new major release.
#
# `key = "environments/prod/terraform.tfstate"` - same bucket as dev,
# different path, so this environment's state can never collide with
# dev's even though both use the identical module.
#
# `use_lockfile = true` is the newer S3-native locking (Terraform 1.10+):
# a small `.tflock` file written next to the state object, using S3's own
# conditional-write guarantee, instead of a separate DynamoDB table.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket       = "visitorcounter-tfstate"
    key          = "environments/prod/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true

    access_key                  = "test"
    secret_key                  = "test"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    use_path_style               = true

    endpoints = {
      s3 = "http://localhost.floci.io:4566"
    }
  }
}

# Points every AWS API call this config makes at floci instead of real AWS.
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

# Same module as dev, DIFFERENT inputs - a different, non-overlapping CIDR
# block, since dev and prod are meant to be genuinely separate networks.
module "app_infra" {
  source = "../../modules/app-infra"

  environment = "prod"
  vpc_cidr    = "10.1.0.0/16"
}

output "vpc_id" {
  value = module.app_infra.vpc_id
}

output "role_arn" {
  value = module.app_infra.role_arn
}

output "public_subnet_ids" {
  value = module.app_infra.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.app_infra.private_subnet_ids
}
