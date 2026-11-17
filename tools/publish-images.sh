#!/bin/bash
# Build, sign and push the gromox-container images.
#
#   tools/publish-images.sh [-c community|supported] [-t TAG] [-b BUILD_ID]
#                           [-r REGISTRY] [-s STAGING_PROJECT] [-n] [--latest]
#                           [--no-sign] [--no-cache] [component...]
#
# Images: <REGISTRY>/<channel>/gromox-<component>:<TAG> and :<TAG>-<BUILD_ID>
# (and :latest with --latest).
#   community  packages from download.grommunio.com/community (public project)
#   supported  packages from download.grommunio.com/supported (private project);
#              needs SUPPORTED_CREDENTIALS=<file> in zypper credentials format:
#                username=<subscription user>
#                password=<subscription password>
#              The file is passed as a BuildKit secret and never stored in an image.
#
# Defaults: REGISTRY=container.grommunio.com, TAG=appVersion of the Helm chart,
# BUILD_ID=UTC date+time, components core archive office. -n builds without
# pushing. --no-cache rebuilds every layer, so that updated packages are
# picked up when the Dockerfiles did not change (used for release builds).
# Log in first: docker login <REGISTRY> (account with push rights).
#
# Signing: every image is signed by digest with cosign (COSIGN_KEY=<private key
# file or KMS URI>, COSIGN_PASSWORD=<key password>) before the moving tags
# (<TAG>, latest) point at it. Pushing without COSIGN_KEY is refused unless
# --no-sign is given.
#
# Staging (-s, Harbor only): for registries that refuse unsigned images, the
# image is pushed and signed in STAGING_PROJECT and then copied into the
# channel project by Harbor (the copy carries the signature and moves the
# tags in one step). Needs HARBOR_USER/HARBOR_PASSWORD for the Harbor API.
set -euo pipefail
cd "$(dirname "$0")/.."

REGISTRY=${REGISTRY:-container.grommunio.com}
CHANNEL=${CHANNEL:-community}
TAG=${TAG:-$(sed -n 's/^appVersion: *"\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' charts/grommunio/Chart.yaml)}
BUILD_ID=${BUILD_ID:-$(date -u +%Y%m%d%H%M)}
STAGING=${STAGING:-}
PUSH=1
LATEST=0
SIGN=1
CACHE=()
while [ $# -gt 0 ]; do
  case "$1" in
    -c) CHANNEL=$2; shift 2 ;;
    -t) TAG=$2; shift 2 ;;
    -b) BUILD_ID=$2; shift 2 ;;
    -r) REGISTRY=$2; shift 2 ;;
    -s) STAGING=$2; shift 2 ;;
    -n) PUSH=0; shift ;;
    --latest) LATEST=1; shift ;;
    --no-sign) SIGN=0; shift ;;
    --no-cache) CACHE=(--no-cache); shift ;;
    -h|--help) sed -n '2,/^set -euo/p' "$0" | sed -n 's/^# \{0,1\}//p'; exit 0 ;;
    -*) echo "unknown option $1" >&2; exit 2 ;;
    *) break ;;
  esac
done
if [ $# -gt 0 ]; then COMPONENTS=("$@"); else COMPONENTS=(core archive office); fi

case "$CHANNEL" in
  community) SECRET=() ;;
  supported)
    [ -r "${SUPPORTED_CREDENTIALS:-}" ] || { echo "CHANNEL=supported needs SUPPORTED_CREDENTIALS=<zypper credentials file>" >&2; exit 2; }
    SECRET=(--secret "id=grommunio_repo,src=${SUPPORTED_CREDENTIALS}") ;;
  *) echo "channel must be community or supported" >&2; exit 2 ;;
esac
for c in "${COMPONENTS[@]}"; do
  [ -f "gromox-${c}/Dockerfile" ] || { echo "unknown component ${c}" >&2; exit 2; }
done
[ -n "$TAG" ] || { echo "no TAG and no appVersion in charts/grommunio/Chart.yaml" >&2; exit 2; }
if [ "$PUSH" = 1 ] && [ "$SIGN" = 1 ]; then
  [ -n "${COSIGN_KEY:-}" ] || { echo "pushing needs COSIGN_KEY (cosign private key) or --no-sign" >&2; exit 2; }
  command -v cosign >/dev/null || { echo "cosign not found" >&2; exit 2; }
fi
if [ "$PUSH" = 1 ] && [ -n "$STAGING" ]; then
  [ -n "${HARBOR_USER:-}" ] && [ -n "${HARBOR_PASSWORD:-}" ] || { echo "-s needs HARBOR_USER and HARBOR_PASSWORD" >&2; exit 2; }
fi

# push one tag and print the manifest digest reported by the registry
push_digest() {
  local out
  out=$(docker push "$1") || { printf '%s\n' "$out" >&2; return 1; }
  printf '%s\n' "$out" >&2
  printf '%s\n' "$out" | sed -n 's/.*digest: \(sha256:[0-9a-f]\{64\}\).*/\1/p' | tail -n 1
}

# Harbor: copy repo@digest from the staging project into the channel project
promote() {
  local repo=$1 digest=$2 code
  code=$(curl -sS -o /dev/stderr -w '%{http_code}' -u "${HARBOR_USER}:${HARBOR_PASSWORD}" -X POST \
    "https://${REGISTRY}/api/v2.0/projects/${CHANNEL}/repositories/${repo}/artifacts?from=${STAGING}/${repo}@${digest}")
  [ "$code" = 201 ] || { echo "promote ${repo}@${digest} failed: HTTP ${code}" >&2; return 1; }
}

REVISION=$(git rev-parse HEAD 2>/dev/null || echo unknown)
CREATED=$(date -u +%Y-%m-%dT%H:%M:%SZ)
for c in "${COMPONENTS[@]}"; do
  repo="gromox-${c}"
  final="${REGISTRY}/${CHANNEL}/${repo}"
  target="${REGISTRY}/${STAGING:-$CHANNEL}/${repo}"
  moving=("${TAG}")
  [ "$LATEST" = 1 ] && moving+=(latest)
  echo ">>> building ${final}:${TAG}-${BUILD_ID} (${CHANNEL})"
  docker build --pull "${CACHE[@]}" \
    --build-arg "GROMMUNIO_CHANNEL=${CHANNEL}" "${SECRET[@]}" \
    --label "org.opencontainers.image.title=${repo}" \
    --label "org.opencontainers.image.version=${TAG}-${BUILD_ID}" \
    --label "org.opencontainers.image.revision=${REVISION}" \
    --label "org.opencontainers.image.created=${CREATED}" \
    --label "org.opencontainers.image.source=https://github.com/grommunio/gromox-container" \
    --label "org.opencontainers.image.vendor=grommunio GmbH" \
    -t "${target}:${TAG}-${BUILD_ID}" -f "gromox-${c}/Dockerfile" .
  [ "$PUSH" = 1 ] || continue

  # push the unique build tag, sign its digest, then move the other tags
  digest=$(push_digest "${target}:${TAG}-${BUILD_ID}")
  [ -n "$digest" ] || { echo "no digest in the push output of ${target}:${TAG}-${BUILD_ID}" >&2; exit 1; }
  if [ "$SIGN" = 1 ]; then
    echo ">>> signing ${target}@${digest}"
    cosign sign --yes --recursive --key "$COSIGN_KEY" \
      -a "org.opencontainers.image.version=${TAG}-${BUILD_ID}" \
      -a "com.grommunio.channel=${CHANNEL}" \
      "${target}@${digest}"
  fi
  for t in "${moving[@]}"; do
    docker tag "${target}:${TAG}-${BUILD_ID}" "${target}:${t}"
    docker push -q "${target}:${t}" > /dev/null
  done
  # Harbor copies image, signature and tags into the channel project
  if [ -n "$STAGING" ]; then
    echo ">>> promoting ${target}@${digest} to ${final}"
    promote "$repo" "$digest"
  fi
  echo ">>> published ${final}:${TAG}-${BUILD_ID} ${digest}"
done
echo ">>> done: ${CHANNEL} ${TAG}-${BUILD_ID}"
