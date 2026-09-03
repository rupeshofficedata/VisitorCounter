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

# Query real, live Availability Zones instead of hardcoding names like
# "us-east-1a" - AZ names/counts differ per region and even per AWS
# account (AZ IDs map to different physical AZ names for different
# accounts), so hardcoding them is a portability trap.
data "aws_availability_zones" "available" {
  state = "available"
}

# Internet Gateway - what actually gives a VPC a path to/from the public
# internet at all. Attached to the VPC, referenced by the public route
# table below.
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name        = "visitorcounter-${var.environment}"
    Environment = var.environment
  }
}

# Public subnets, one per AZ (2 AZs). cidrsubnet() carves a /24 out of
# whatever /16 this environment's vpc_cidr is, using count.index to pick
# a different slice each time - no hardcoded per-environment subnet
# ranges needed, the same module code works for any vpc_cidr passed in.
resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.this.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block               = cidrsubnet(var.vpc_cidr, 8, count.index * 2)
  map_public_ip_on_launch = true

  tags = {
    Name        = "visitorcounter-${var.environment}-public-${count.index}"
    Environment = var.environment
    Tier        = "public"
  }
}

# Private subnets, one per AZ - offset by 1 in the cidrsubnet math so
# public/private pairs interleave (0,2 = public; 1,3 = private) rather
# than colliding.
resource "aws_subnet" "private" {
  count = 2

  vpc_id            = aws_vpc.this.id
  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index * 2 + 1)

  tags = {
    Name        = "visitorcounter-${var.environment}-private-${count.index}"
    Environment = var.environment
    Tier        = "private"
  }
}

# One route table for both public subnets: default route (0.0.0.0/0)
# points at the Internet Gateway - this is what actually MAKES a subnet
# "public", not the map_public_ip_on_launch flag alone (that just
# auto-assigns a public IP; without this route, that IP would be
# unreachable from the internet anyway).
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name        = "visitorcounter-${var.environment}-public"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private route table: deliberately NO default route. Outbound internet
# access for private subnets needs a NAT Gateway - a real, separate,
# heavier resource, intentionally not built today (VisitorCounter's
# current shape doesn't need it yet, and it's slow to provision even in
# an emulator). Without a NAT Gateway, this table just gets the implicit
# "local" route Terraform/AWS adds automatically - traffic within the
# VPC works, nothing else does.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name        = "visitorcounter-${var.environment}-private"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "private" {
  count = 2

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Security Group for wherever VisitorCounter's app would actually run.
# STATEFUL: this inbound rule is the only one needed - a reply to an
# already-allowed inbound connection is automatically permitted back out,
# with no matching egress rule required. Contrast with the NACL below.
resource "aws_security_group" "app" {
  name        = "visitorcounter-${var.environment}-app"
  description = "Allow VisitorCounter app traffic from within the VPC"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "VisitorCounter app port, VPC-internal only"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "visitorcounter-${var.environment}-app"
    Environment = var.environment
  }
}

# Network ACL on the public subnets. STATELESS: unlike the SG above, an
# inbound-allow rule does NOT automatically permit the matching reply
# back out - the ephemeral-port egress rule below is what makes return
# traffic possible at all. Miss it, and connections would appear to
# "accept" but responses could never leave the subnet.
resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.this.id
  subnet_ids = aws_subnet.public[*].id

  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 5000
    to_port    = 5000
  }

  # Without this, a client's reply on its own ephemeral source port
  # would be silently dropped LEAVING the subnet - the request could
  # arrive, but the response could never get back out. This is exactly
  # the kind of rule a stateful-only mental model (carried over from SGs)
  # leads people to forget in real incidents.
  egress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  tags = {
    Name        = "visitorcounter-${var.environment}-public"
    Environment = var.environment
  }
}

# VisitorCounter's IAM role - trust policy (who can assume it).
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

# A believable real use case for permissions: if VisitorCounter logged
# visit events to S3 for analytics, this is the bucket it would write to.
resource "aws_s3_bucket" "logs" {
  bucket = "visitorcounter-${var.environment}-logs"

  tags = {
    Name        = "visitorcounter-${var.environment}-logs"
    Environment = var.environment
  }
}

# The actual least-privilege policy: only this ONE bucket, only the
# actions actually needed - not S3FullAccess, not a wildcard resource.
# Built with the aws_iam_policy_document data source (not raw jsonencode)
# so a typo in an action/resource name is caught at `plan` time.
data "aws_iam_policy_document" "app_permissions" {
  # Object-level actions (reading/writing individual files) need the
  # bucket ARN with /* appended - the object path lives inside that.
  statement {
    sid       = "ReadWriteLogObjects"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${aws_s3_bucket.logs.arn}/*"]
  }

  # Bucket-level actions (like listing what's inside it) use the bucket's
  # own ARN directly - no /* - since this action isn't about one object.
  statement {
    sid       = "ListLogBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.logs.arn]
  }
}

# Inline policy - glued to this one role specifically. Appropriate here
# since nothing else needs these exact permissions; a standalone
# aws_iam_policy + aws_iam_role_policy_attachment would be the better
# choice the moment a second role needed the same access.
resource "aws_iam_role_policy" "app_permissions" {
  name   = "visitorcounter-${var.environment}-s3-logs"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.app_permissions.json
}
