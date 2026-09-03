# Outputs are how a module hands values back to whatever calls it - without
# these, the calling config would have no way to reference the VPC/role
# this module created (e.g. to attach other resources to them later).

output "vpc_id" {
  value = aws_vpc.this.id
}

output "role_arn" {
  value = aws_iam_role.this.arn
}

output "role_name" {
  value = aws_iam_role.this.name
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}
