#!/bin/bash
# First-boot setup of the app host (Terraform templatefile). Releases are not
# installed here: the CD job pushes images to ECR and runs deploy-release.sh
# on this host through SSM Run Command.
set -euxo pipefail

dnf install -y docker
# Docker starts at boot, and with restart: unless-stopped it brings the app
# containers back after a reboot or a lab restart without a new deployment.
systemctl enable --now docker

# Amazon Linux has no Docker Compose package; install the official plugin
# binary and check it against the published SHA-256.
mkdir -p /usr/local/lib/docker/cli-plugins
cd /usr/local/lib/docker/cli-plugins
base=https://github.com/docker/compose/releases/download/${compose_version}
curl -fsSLo docker-compose $base/docker-compose-linux-x86_64
echo "$(curl -fsSL $base/docker-compose-linux-x86_64.sha256 | cut -d' ' -f1)  docker-compose" | sha256sum -c
chmod +x docker-compose
docker compose version

mkdir -p /opt/service-book
cat > /opt/service-book/health-metric.sh <<'SCRIPT'
${health_script}
SCRIPT
cat > /etc/systemd/system/service-book-health.service <<'UNIT'
${health_service}
UNIT
cat > /etc/systemd/system/service-book-health.timer <<'UNIT'
${health_timer}
UNIT
systemctl daemon-reload
systemctl enable --now service-book-health.timer
