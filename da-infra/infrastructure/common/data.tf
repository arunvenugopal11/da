data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Look up the VPC by the Name tag — set this tag on your VPC in the console
# or via bootstrap Terraform before running other modules
data "aws_vpc" "main" {
  tags = {
    Name = "da-${var.env_name}-vpc"
  }
}

# Private subnets — tagged during VPC creation
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
  tags = {
    Tier = "private"
  }
}

# Public subnets
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
  tags = {
    Tier = "public"
  }
}
