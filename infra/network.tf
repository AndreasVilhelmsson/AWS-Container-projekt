###############################################
# NETWORK (reuse existing default VPC + subnets)
###############################################

# Inputs från variables.tf / terraform.tfvars
# - var.vpc_id
# - var.public_subnet_ids = [subnet-..., subnet-...]

# 1) Hämta din VPC (validerar att VPC finns)
data "aws_vpc" "selected" {
  id = var.vpc_id
}

# (Valfritt) IGW, endast som referens – skapas inte
data "aws_internet_gateway" "for_vpc" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.selected.id]
  }
}

# Outputs – används av ALB/ECS
output "vpc_id" {
  value = data.aws_vpc.selected.id
}

output "public_subnet_ids" {
  # Använd de värden du sätter i terraform.tfvars rakt av
  value = var.public_subnet_ids
}
