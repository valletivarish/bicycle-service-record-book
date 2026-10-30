#!/bin/bash
# First-boot setup of the API host (Terraform templatefile). Releases are not
# installed here: the CD job pushes an image to ECR and runs
# deploy-container.sh on this host through SSM Run Command.
set -euxo pipefail

dnf install -y docker nginx
systemctl enable --now docker

mkdir -p /opt/service-book
cat > /etc/nginx/conf.d/service-book.conf <<'NGINX'
${nginx_conf}
NGINX
nginx -t
systemctl enable --now nginx

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
