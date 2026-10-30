data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_ecr_repository" "api" {
  name = "service-book-api"
}

resource "aws_instance" "api" {
  ami                    = data.aws_ssm_parameter.al2023_ami.value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = var.instance_profile

  # Installs Docker and Nginx, writes the /api/ proxy config and the health
  # metric timer. Releases arrive later through SSM Run Command.
  user_data = templatefile("${path.module}/../../scripts/ec2-user-data.sh", {
    nginx_conf     = file("${path.module}/../nginx/api-proxy.conf")
    health_script  = file("${path.module}/../../scripts/health-metric.sh")
    health_service = file("${path.module}/../systemd/service-book-health.service")
    health_timer   = file("${path.module}/../systemd/service-book-health.timer")
  })

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
  }

  # A newer AMI or user data must not replace the running host on every apply.
  lifecycle {
    ignore_changes = [ami, user_data]
  }

  tags = { Name = "service-book-api" }
}

# Stable address for the API host, kept for the whole assessment period.
# CloudFront reaches the host through this address's public DNS name.
resource "aws_eip" "api" {
  domain = "vpc"
  tags   = { Name = "service-book-api" }
}

resource "aws_eip_association" "api" {
  instance_id   = aws_instance.api.id
  allocation_id = aws_eip.api.id
}
