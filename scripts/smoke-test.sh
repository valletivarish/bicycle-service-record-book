#!/bin/bash
# Post-deploy check through CloudFront: smoke-test.sh <app-url> [expected-release]
# Covers S3 + CloudFront routing, Nginx, the Node API and RDS. The throwaway
# record is always deleted, even when a check fails.
set -euo pipefail
BASE=${1%/}
RELEASE=${2:-}
fail() { echo "FAIL: $1"; exit 1; }

# An empty release means this run did not deploy the API, so any release is fine.
curl -fsS "$BASE/api/health" | jq -e --arg r "$RELEASE" '.status == "ok" and ($r == "" or .release == $r)' >/dev/null \
  || fail "health does not report release $RELEASE"
echo "ok   health is ok (release ${RELEASE:-unchanged})"

for path in / /records/1 /records/new; do
  curl -fsS "$BASE$path" | grep -q '<app-root>' || fail "$path is not the Angular app"
done
echo "ok   Angular app served at / and on deep links"

code=$(curl -s -o /tmp/notfound.json -w '%{http_code}' "$BASE/api/records/2147483647")
[ "$code" = 404 ] && jq -e .error /tmp/notfound.json >/dev/null || fail "API 404 was not JSON ($code)"
echo "ok   API 404 stays JSON (not rewritten to index.html)"

TODAY=$(TZ=Europe/Dublin date +%F)
BODY="{\"bicycleLabel\":\"SMOKE-$(date +%s)\",\"serviceDate\":\"$TODAY\",\"workDescription\":\"Created by the CD smoke test\",\"cost\":\"1.00\"}"
ID=$(curl -fsS -X POST "$BASE/api/records" -H 'Content-Type: application/json' -d "$BODY" | jq -r .id)
trap 'curl -s -o /dev/null -X DELETE "$BASE/api/records/$ID"' EXIT
echo "ok   created record $ID"

curl -fsS "$BASE/api/records/$ID" | jq -e '.cost == "1.00"' >/dev/null || fail "read back"
curl -fsS -X PUT "$BASE/api/records/$ID" -H 'Content-Type: application/json' \
  -d "${BODY%\}},\"status\":\"Collected\"}" | jq -e '.status == "Collected"' >/dev/null || fail "update"
echo "ok   read and updated record $ID"

code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/records" \
  -H 'Content-Type: application/json' -d '{"bicycleLabel":"","cost":"-5"}')
[ "$code" = 422 ] || fail "invalid input returned $code instead of 422"
echo "ok   invalid input rejected with 422"

[ "$(curl -s -o /dev/null -w '%{http_code}' -X DELETE "$BASE/api/records/$ID")" = 204 ] || fail "delete"
[ "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/api/records/$ID")" = 404 ] || fail "still found"
trap - EXIT
echo "ok   deleted record $ID and confirmed it is gone"
