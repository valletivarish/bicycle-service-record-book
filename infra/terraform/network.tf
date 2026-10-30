resource "aws_vpc" "main" {
  # checkov:skip=CKV2_AWS_11:flow logs would add log storage cost; SG rules and CloudFront are the access controls here
  cidr_block           = "10.20.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "service-book" }
}

# The default security group is left with no rules so nothing can use it.
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

# One public subnet for the EC2 host (it needs internet access to pull images
# from ECR and packages). No NAT gateway: nothing else needs outbound access.
resource "aws_subnet" "public" {
  # checkov:skip=CKV_AWS_130:the host needs a public IP at first boot to install packages before the Elastic IP is associated
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.20.1.0/24"
  availability_zone       = var.availability_zones[0]
  map_public_ip_on_launch = true
  tags                    = { Name = "service-book-public" }
}

# RDS needs a subnet group spanning two availability zones.
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.20.${count.index + 11}.0/24"
  availability_zone = var.availability_zones[count.index]
  tags              = { Name = "service-book-private-${count.index}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "web" {
  name        = "service-book-web"
  description = "HTTP from CloudFront to Nginx on the API host"
  vpc_id      = aws_vpc.main.id

  # Only CloudFront's origin-facing addresses can reach Nginx, so the API
  # cannot be called directly on the Elastic IP, bypassing HTTPS.
  ingress {
    description     = "HTTP from CloudFront origin servers"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront.id]
  }

  # HTTPS out covers ECR, SSM, S3, CloudWatch and the dnf repositories.
  egress {
    description = "HTTPS to AWS APIs and package repositories"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "PostgreSQL to RDS inside the VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }
}

data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group" "db" {
  name        = "service-book-db"
  description = "PostgreSQL from the API host only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from the web security group"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }
}
