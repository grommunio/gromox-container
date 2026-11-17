#!/bin/bash
# Package, push and sign the Helm chart.
#
#   tools/publish-chart.sh [-r REGISTRY] [-p PROJECT] [-s STAGING_PROJECT] [-v VERSION] [--no-sign]
#
# Pushes oci://<REGISTRY>/<PROJECT>/charts/grommunio:<VERSION> (default
# container.grommunio.com, community, version from Chart.yaml) and signs it
# by digest with cosign (COSIGN_KEY, COSIGN_PASSWORD). cosign uses the docker
# credentials: docker login <REGISTRY> and helm registry login <REGISTRY>.
#
# With -s (Harbor only) the chart is pushed and signed in STAGING_PROJECT and
# then copied into PROJECT together with its signature (HARBOR_USER,
# HARBOR_PASSWORD), for registries that refuse unsigned artifacts.
set -euo pipefail
cd "$(dirname "$0")/.."

REGISTRY=${REGISTRY:-container.grommunio.com}
PROJECT=${PROJECT:-community}
STAGING=${STAGING:-}
VERSION=${VERSION:-}
SIGN=1
while [ $# -gt 0 ]; do
  case "$1" in
    -r) REGISTRY=$2; shift 2 ;;
    -p) PROJECT=$2; shift 2 ;;
    -s) STAGING=$2; shift 2 ;;
    -v) VERSION=$2; shift 2 ;;
    --no-sign) SIGN=0; shift ;;
    -h|--help) sed -n '2,/^set -euo/p' "$0" | sed -n 's/^# \{0,1\}//p'; exit 0 ;;
    *) echo "unknown argument $1" >&2; exit 2 ;;
  esac
done
if [ "$SIGN" = 1 ]; then
  [ -n "${COSIGN_KEY:-}" ] || { echo "needs COSIGN_KEY or --no-sign" >&2; exit 2; }
fi
if [ -n "$STAGING" ]; then
  [ -n "${HARBOR_USER:-}" ] && [ -n "${HARBOR_PASSWORD:-}" ] || { echo "-s needs HARBOR_USER and HARBOR_PASSWORD" >&2; exit 2; }
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
helm package charts/grommunio -d "$tmp" ${VERSION:+--version "$VERSION"} > /dev/null
pkg=$(ls "$tmp"/grommunio-*.tgz)
target="${REGISTRY}/${STAGING:-$PROJECT}/charts"
out=$(helm push "$pkg" "oci://${target}" 2>&1) || { printf '%s\n' "$out" >&2; exit 1; }
printf '%s\n' "$out"
digest=$(printf '%s\n' "$out" | sed -n 's/^Digest: \(sha256:[0-9a-f]\{64\}\)$/\1/p')
[ -n "$digest" ] || { echo "no digest in the helm push output" >&2; exit 1; }

if [ "$SIGN" = 1 ]; then
  cosign sign --yes --key "$COSIGN_KEY" "${target}/grommunio@${digest}"
fi
if [ -n "$STAGING" ]; then
  code=$(curl -sS -o /dev/stderr -w '%{http_code}' -u "${HARBOR_USER}:${HARBOR_PASSWORD}" -X POST \
    "https://${REGISTRY}/api/v2.0/projects/${PROJECT}/repositories/charts%252Fgrommunio/artifacts?from=${STAGING}/charts/grommunio@${digest}")
  [ "$code" = 201 ] || { echo "promote failed: HTTP ${code}" >&2; exit 1; }
fi
echo ">>> published oci://${REGISTRY}/${PROJECT}/charts/grommunio ${digest}"
