#!/bin/bash
# Runs on the EC2 host through SSM Run Command, sent by the CD job:
#   deploy-release.sh <registry> <api-tag|-> <web-tag|->
# "-" keeps the tag that is running now (that part did not change). Starts
# both containers with Docker Compose and checks the app through the web
# container. If the release is not healthy within 60 s, the previous tags are
# started again and the script exits 1.
set -euo pipefail
REGISTRY=$1
API_TAG=$2
WEB_TAG=$3
STATE=/opt/service-book
REGION=us-east-1
cd $STATE

current() { sed -n "s/^$1=//p" .env 2>/dev/null || true; }
[ "$API_TAG" = - ] && API_TAG=$(current API_TAG)
[ "$WEB_TAG" = - ] && WEB_TAG=$(current WEB_TAG)
if [ -z "$API_TAG" ] || [ -z "$WEB_TAG" ]; then
  echo "no running release yet: the first deployment needs both image tags"
  exit 1
fi

DB_HOST=$(aws ssm get-parameter --region $REGION --name /service-book/db/host \
  --with-decryption --query Parameter.Value --output text)
DB_PASSWORD=$(aws ssm get-parameter --region $REGION --name /service-book/db/password \
  --with-decryption --query Parameter.Value --output text)
# The API verifies the RDS certificate against this AWS CA bundle (DB_SSL).
curl -fsS -o rds-ca.pem https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem
chmod 644 rds-ca.pem
# Root-only env file, so the password is not on any command line.
install -m 600 /dev/null api.env
cat > api.env <<ENV
PGHOST=$DB_HOST
PGUSER=servicebook
PGPASSWORD=$DB_PASSWORD
PGDATABASE=servicebook
DB_SSL=true
ENV

aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin "$REGISTRY"

# Tags are passed as environment variables (they win over .env), and .env is
# only rewritten once a release has passed its health check.
start() {
  export REGISTRY API_TAG=$1 WEB_TAG=$2
  docker compose -f compose.aws.yml pull --quiet && docker compose -f compose.aws.yml up -d
}

healthy() {
  for _ in $(seq 1 30); do
    if curl -fsS -m 3 http://127.0.0.1/api/health | grep -q "\"release\":\"$1\"" &&
      curl -fsS -m 3 http://127.0.0.1/ | grep -q '<app-root>'; then
      return 0
    fi
    sleep 2
  done
  return 1
}

save() {
  printf 'REGISTRY=%s\nAPI_TAG=%s\nWEB_TAG=%s\n' "$REGISTRY" "$1" "$2" > .env
}

PREV_API=$(current API_TAG)
PREV_WEB=$(current WEB_TAG)

if start "$API_TAG" "$WEB_TAG" && healthy "$API_TAG"; then
  if [ -f .env ] && [ "$PREV_API $PREV_WEB" != "$API_TAG $WEB_TAG" ]; then
    cp .env previous.env
  fi
  save "$API_TAG" "$WEB_TAG"
  # Old images are removed from the disk; ECR keeps the last 10 for rollback.
  docker image prune -af --filter "until=24h" >/dev/null || true
  echo "release api=$API_TAG web=$WEB_TAG is healthy"
  exit 0
fi

echo "release api=$API_TAG web=$WEB_TAG failed its health check"
docker compose -f compose.aws.yml logs --tail 30 api || true
if [ -n "$PREV_API" ]; then
  echo "rolling back to api=$PREV_API web=$PREV_WEB"
  start "$PREV_API" "$PREV_WEB"
  if healthy "$PREV_API"; then echo "rollback is healthy"; else echo "rollback is NOT healthy"; fi
fi
exit 1
