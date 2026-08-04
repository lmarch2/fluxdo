#!/usr/bin/env bash

set -euo pipefail

ARCHIVE_PATH="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
STAGE_ROOT="${PROJECT_ROOT}/flatpak/stage"

if [[ -z "${ARCHIVE_PATH}" || ! -f "${ARCHIVE_PATH}" ]]; then
  echo "Usage: $0 <bundle-archive>" >&2
  exit 1
fi

rm -rf "${STAGE_ROOT}"
mkdir -p "${STAGE_ROOT}"

tar -xzf "${ARCHIVE_PATH}" -C "${STAGE_ROOT}"

if [[ ! -x "${STAGE_ROOT}/bundle/idcflare" ]]; then
  echo "Expected executable not found after extraction: ${STAGE_ROOT}/bundle/idcflare" >&2
  exit 1
fi
