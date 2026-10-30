resource "random_password" "db" {
  length  = 32
  special = false
}

resource "aws_db_subnet_group" "main" {
  name       = "service-book"
  subnet_ids = aws_subnet.private[*].id
}

# Single-AZ db.t3.micro with 20 GB gp3: a small desk app with a few writes a
# day does not need Multi-AZ, which would double the always-on database.
resource "aws_db_instance" "main" {
  identifier             = "service-book"
  engine                 = "postgres"
  engine_version         = "16"
  instance_class         = var.db_instance_class
  allocated_storage      = 20
  storage_type           = "gp3"
  db_name                = "servicebook"
  username               = "servicebook"
  password               = random_password.db.result
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
}

# The deploy script on EC2 reads these when it starts a container, so the
# database password never passes through GitHub or the browser bundle.
resource "aws_ssm_parameter" "db_host" {
  name  = "/service-book/db/host"
  type  = "String"
  value = aws_db_instance.main.address
}

resource "aws_ssm_parameter" "db_password" {
  name  = "/service-book/db/password"
  type  = "SecureString"
  value = random_password.db.result
}
