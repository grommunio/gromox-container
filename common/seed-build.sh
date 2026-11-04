#!/bin/bash
# Build-time helper (Dockerfile RUN): snapshot the package-provided content of
# the paths that are mounted as volumes at runtime into SEED_DIR. The
# entrypoints restore it into empty volumes (see seed_volume in helpers):
# Kubernetes persistent volumes start out empty, Docker named volumes do not.
set -e
SEED_DIR="${SEED_DIR:-/usr/share/gromox-container/seed}"
for p in "$@"; do
  mkdir -p "${SEED_DIR}$(dirname "$p")"
  if [ -e "$p" ]; then
    cp -a "$p" "${SEED_DIR}$(dirname "$p")/"
  else
    # make sure the runtime directory exists even if the package does not ship it
    mkdir -p "${SEED_DIR}$p"
  fi
done
du -sh "${SEED_DIR}"
