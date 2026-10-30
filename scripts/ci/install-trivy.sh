#!/bin/bash
# install-trivy.sh <version>: official release archive, checked against the
# published checksums before it is installed.
set -euo pipefail
VERSION=$1
cd /tmp
base=https://github.com/aquasecurity/trivy/releases/download/v$VERSION
curl -fsSLO "$base/trivy_${VERSION}_Linux-64bit.tar.gz"
curl -fsSLO "$base/trivy_${VERSION}_checksums.txt"
sha256sum --check --ignore-missing "trivy_${VERSION}_checksums.txt"
tar -xzf "trivy_${VERSION}_Linux-64bit.tar.gz" trivy
sudo install trivy /usr/local/bin/trivy
