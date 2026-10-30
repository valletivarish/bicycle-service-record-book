#!/bin/bash
# Runs on the EC2 host through SSM Run Command, sent by the CD job:
#   deploy-container.sh <ecr-repository-url> <image-tag>
# Pulls the new image, swaps the container and checks /api/health. If the new
# release is not healthy within 60 s, the previous image tag is started again.
set -euo pipefail
REPO=$1
TAG=$2
NAME=service-book-api
STATE=/opt/service-book
REGION=us-east-1

DB_HOST=$(aws ssm get-parameter --region $REGION --name /service-book/db/host \
  --query Parameter.Value --output text)
DB_PASSWORD=$(aws ssm get-parameter --region $REGION --name /service-book/db/password \
  --with-decryption --query Parameter.Value --output text)
# The API verifies the RDS certificate against this AWS CA bundle (DB_SSL).
curl -fsS -o $STATE/rds-ca.pem https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem
# Settings go into a root-only env file, so the password is not on any
# command line (docker run arguments are visible in the process list).
install -m 600 /dev/null $STATE/api.env
cat > $STATE/api.env <<ENV
PGHOST=$DB_HOST
PGUSER=servicebook
PGPASSWORD=$DB_PASSWORD
PGDATABASE=servicebook
DB_SSL=true
ENV

aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin "${REPO%%/*}"

start() {
  docker rm -f $NAME >/dev/null 2>&1 || true
  docker run -d --name $NAME --restart unless-stopped \
    -p 127.0.0.1:3000:3000 \
    -v $STATE/rds-ca.pem:/certs/rds-ca.pem:ro \
    --env-file $STATE/api.env -e RELEASE_ID="$1" \
    "$REPO:$1"
}

healthy() {
  for _ in $(seq 1 30); do
    if curl -fsS -m 3 http://127.0.0.1/api/health | grep -q "\"release\":\"$1\""; then
      return 0
    fi
    sleep 2
  done
  return 1
}

PREVIOUS=$(cat $STATE/current-tag 2>/dev/null || true)
docker pull "$REPO:$TAG"
start "$TAG"

if healthy "$TAG"; then
  echo "$TAG" > $STATE/current-tag
  [ -n "$PREVIOUS" ] && echo "$PREVIOUS" > $STATE/previous-tag
  # Keep only the running image and the rollback image on the 20 GB disk.
  docker image prune -af --filter "until=1h" >/dev/null || true
  echo "release $TAG is healthy"
  exit 0
fi

echo "release $TAG failed its health check"
docker logs --tail 50 $NAME || true
if [ -n "$PREVIOUS" ]; then
  echo "rolling back to $PREVIOUS"
  start "$PREVIOUS"
  healthy "$PREVIOUS" && echo "rollback to $PREVIOUS is healthy"
fi
exit 1
