# Deliberately NO provider block in here. A module inherits whichever
# provider connection the config that CALLS it has already configured -
# a module hardcoding its own provider would mean every environment is
# forced through the same AWS account/credentials/region, which defeats
# the point of having separate environments at all.

# VisitorCounter's VPC, parameterized per environment instead of hardcoded
# once - this is the whole point of a module: write the shape once, reuse
# it with different inputs for dev/prod instead of copy-pasting the file.
resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  tags = {
    Name        = "visitorcounter-${var.environment}"
    Environment = var.environment
  }
}

# VisitorCounter's IAM role, same pattern - trust policy only, no
# permissions attached (real least-privilege policy design is Day 7).
resource "aws_iam_role" "this" {
  name = "visitorcounter-${var.environment}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "visitorcounter-${var.environment}"
    Environment = var.environment
  }
}
