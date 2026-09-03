# Pins the AWS provider so `terraform init` always installs a known, tested
# version instead of silently picking up a new major release.
#
# `key = "environments/dev/terraform.tfstate"` is what actually gives dev
# its own isolated state, separate from prod's - same bucket, different
# path inside it.
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
    key          = "environments/dev/terraform.tfstate"
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
# The module called below has no provider block of its own - it inherits
# this one.
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

# Calls the shared module with dev-specific inputs - this whole file is
# just wiring: which module, which backend, which variable values. No
# resources are defined directly here.
module "app_infra" {
  source = "../../modules/app-infra"

  environment = "dev"
  vpc_cidr    = "10.0.0.0/16"
}

# Re-expose the module's outputs at this level so `terraform output` here
# shows something useful without needing to dig into the module.
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
