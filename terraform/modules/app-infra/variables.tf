# Which environment this module instance belongs to - drives naming/tags,
# not resource behavior itself (e.g. dev and prod get identically-shaped
# infra, just labeled and CIDR'd differently).
variable "environment" {
  type        = string
  description = "Environment name, e.g. \"dev\" or \"prod\"."
}

# Each environment needs a non-overlapping CIDR block - required input,
# no default, so a caller can never forget to think about it.
variable "vpc_cidr" {
  type        = string
  description = "CIDR block for this environment's VPC."
}
