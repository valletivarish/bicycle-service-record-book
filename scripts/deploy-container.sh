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
# verify-full checks the RDS certificate against the AWS CA bundle.
curl -fsS -o $STATE/rds-ca.pem https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem
DATABASE_URL="postgres://servicebook:$DB_PASSWORD@$DB_HOST:5432/servicebook?sslmode=verify-full&sslrootcert=/certs/rds-ca.pem"

aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin "${REPO%%/*}"

start() {
  docker rm -f $NAME >/dev/null 2>&1 || true
  docker run -d --name $NAME --restart unless-stopped \
    -p 127.0.0.1:3000:3000 \
    -v $STATE/rds-ca.pem:/certs/rds-ca.pem:ro \
    -e DATABASE_URL="$DATABASE_URL" -e RELEASE_ID="$1" \
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
