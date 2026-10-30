#!/bin/bash
# Manual recovery on the EC2 host (SSM Run Command or Session Manager):
# starts the release recorded in previous.env again. Running it a second time
# goes forward again, because the deploy script records the swapped release.
set -euo pipefail
STATE=/opt/service-book
tag() { sed -n "s/^$1=//p" "$STATE/$2"; }
bash "$STATE/deploy-release.sh" "$(tag REGISTRY previous.env)" \
  "$(tag API_TAG previous.env)" "$(tag WEB_TAG previous.env)"
