data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "service-book" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

# One public subnet for the EC2 host (it needs internet access to pull images
# from ECR and packages). No NAT gateway: nothing else needs outbound access.
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.20.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags                    = { Name = "service-book-public" }
}

# RDS needs a subnet group spanning two availability zones.
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.20.${count.index + 11}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
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

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
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
