data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# One repository per image: the API and the web (Nginx + Angular) image.
# Tags are commit SHAs and are never reused, so they can be immutable.
resource "aws_ecr_repository" "app" {
  # checkov:skip=CKV_AWS_136:default AES-256 encryption is enough for app images; a KMS key adds a monthly charge
  for_each             = toset(["service-book-api", "service-book-web"])
  name                 = each.key
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Only the last 10 images per repository are kept: enough for rollback
# without storing every build forever.
resource "aws_ecr_lifecycle_policy" "app" {
  for_each   = aws_ecr_repository.app
  repository = each.value.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "keep last 10 images"
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 10 }
      action       = { type = "expire" }
    }]
  })
}

resource "aws_instance" "api" {
  # checkov:skip=CKV_AWS_126:basic 5-minute metrics are enough for the CPU alarm; detailed monitoring is billed per metric
  ami                    = data.aws_ssm_parameter.al2023_ami.value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = var.instance_profile
  ebs_optimized          = true

  # IMDSv2 only: the health script already asks for a session token.
  metadata_options {
    http_tokens = "required"
  }

  # Installs Docker, the Compose plugin and the health metric timer.
  # Releases (two containers) arrive later through SSM Run Command.
  user_data = templatefile("${path.module}/../../scripts/ec2-user-data.sh", {
    compose_version = var.compose_version
    health_script   = file("${path.module}/../../scripts/health-metric.sh")
    health_service  = file("${path.module}/../systemd/service-book-health.service")
    health_timer    = file("${path.module}/../systemd/service-book-health.timer")
  })

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  # A newer AMI or user data must not replace the running host on every apply.
  lifecycle {
    ignore_changes = [ami, user_data]
  }

  tags = { Name = "service-book-api" }
}

# Stable public address of the app (http://<elastic-ip>/), kept for the
# whole assessment period and re-associated if the instance is replaced.
resource "aws_eip" "api" {
  domain = "vpc"
  tags   = { Name = "service-book-api" }
}

resource "aws_eip_association" "api" {
  instance_id   = aws_instance.api.id
  allocation_id = aws_eip.api.id
}
