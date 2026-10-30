#!/bin/bash
# Manual recovery, run on the EC2 host (SSM Session Manager or Run Command):
# starts the image recorded as the previous good release again.
set -euo pipefail
STATE=/opt/service-book
PREVIOUS=$(cat $STATE/previous-tag)
REPO=$(docker inspect --format '{{.Config.Image}}' service-book-api | cut -d: -f1)
bash "$(dirname "$0")/deploy-container.sh" "$REPO" "$PREVIOUS"
