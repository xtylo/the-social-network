# Networking on the account's default VPC. No NAT Gateway: it alone would cost more than the whole budget.

data "aws_vpc" "default" {
  default = true
}

# Default subnets, limited to Availability Zones that support Lambda in a VPC.
# Zone IDs (use1-az1...) are the same for every account; zone names (us-east-1a...) are shuffled per account.
# use1-az3 does not support Lambda VPC networking, so it is left out.
data "aws_subnets" "supported" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "availability-zone-id"
    values = ["use1-az1", "use1-az2", "use1-az4", "use1-az6"]
  }
}

data "aws_route_tables" "default" {
  vpc_id = data.aws_vpc.default.id
}

# Lambdas: no inbound rules (API Gateway invokes them through AWS, not through the network).
resource "aws_security_group" "lambda" {
  name        = "${var.project}-lambda"
  description = "Lambda functions of the social network"
  vpc_id      = data.aws_vpc.default.id

  egress {
    description = "All outbound (PostgreSQL and the S3 endpoint)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# PostgreSQL: only the Lambdas and your own IP can connect.
resource "aws_security_group" "db" {
  name        = "${var.project}-db"
  description = "PostgreSQL for the social network"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "PostgreSQL from the Lambdas"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  ingress {
    description = "PostgreSQL from my IP (psql, schema and seed)"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Free S3 gateway endpoint: lets Lambdas inside the VPC reach S3 without a NAT Gateway.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = data.aws_vpc.default.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = data.aws_route_tables.default.ids
}
