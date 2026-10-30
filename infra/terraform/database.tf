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
  # checkov:skip=CKV_AWS_157:Multi-AZ would double the always-on database for a low-traffic desk app
  # checkov:skip=CKV_AWS_161:IAM database auth needs IAM roles, which the Learner Lab cannot create
  # checkov:skip=CKV_AWS_118:enhanced monitoring needs an IAM monitoring role (not allowed in the lab)
  # checkov:skip=CKV_AWS_353:Performance Insights is not needed for a few queries a day
  # checkov:skip=CKV_AWS_129:log exports to CloudWatch add storage cost; the API logs its own errors
  # checkov:skip=CKV2_AWS_30:query logging would log every statement for little value at this size
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
  storage_encrypted      = true
  deletion_protection    = true
  copy_tags_to_snapshot  = true
  # Minor versions bring security fixes; they install in the maintenance window.
  auto_minor_version_upgrade = true
  backup_retention_period    = 7
  skip_final_snapshot        = false
  final_snapshot_identifier  = "service-book-final"
}

# The deploy script on EC2 reads these when it starts a container, so the
# database password never passes through GitHub or the browser bundle.
resource "aws_ssm_parameter" "db_host" {
  # checkov:skip=CKV_AWS_337:same as the password: the AWS managed aws/ssm key is used
  name  = "/service-book/db/host"
  type  = "SecureString"
  value = aws_db_instance.main.address
}

resource "aws_ssm_parameter" "db_password" {
  # checkov:skip=CKV_AWS_337:the AWS managed aws/ssm key encrypts it; a customer key adds cost and key policy work
  name  = "/service-book/db/password"
  type  = "SecureString"
  value = random_password.db.result
}
