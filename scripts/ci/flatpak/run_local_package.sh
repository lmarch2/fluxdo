#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
ARTIFACT_PATH="${PROJECT_ROOT}/.artifacts/flatpak/fluxidc-flatpak-source-tree.tar.gz"
CONTAINER_IMAGE="${FLATPAK_CI_IMAGE:-ghcr.io/flathub-infra/flatpak-github-actions:gnome-48}"
OUTPUT_BUNDLE="${PROJECT_ROOT}/fluxidc-linux-x86_64.flatpak"
WPE_LAYER_ASSET="fluxidc-flatpak-wpe-layer-gnome48-x86_64.tar.zst"
WPE_LAYER_VERSION_FILE="${PROJECT_ROOT}/flatpak/wpe-layer.version"

detect_github_repo() {
  if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
    printf '%s\n' "${GITHUB_REPOSITORY}"
    return
  fi

  local remote_url
  remote_url="$(git -C "${PROJECT_ROOT}" config --get remote.origin.url 2>/dev/null || true)"

  if [[ "${remote_url}" =~ github\.com[:/]([^/]+/[^/.]+)(\.git)?$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return
  fi

  echo "Unable to detect a GitHub repository; set GITHUB_REPOSITORY or WPE_LAYER_BASE_URL." >&2
  return 1
}

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required" >&2
  exit 1
fi

cd "${PROJECT_ROOT}"

cleanup_generated_artifacts() {
  local paths=(
    flatpak/stage/source-tree
    flatpak/stage/wpe-layer
    flatpak_app
    repo
    "${OUTPUT_BUNDLE}"
  )

  if rm -rf "${paths[@]}" 2>/dev/null; then
    return
  fi

  echo "==> Falling back to container cleanup for root-owned build artifacts"
  docker run --rm \
    -v "${PROJECT_ROOT}:/workspace" \
    "${CONTAINER_IMAGE}" \
    sh -lc 'rm -rf /workspace/flatpak/stage/source-tree /workspace/flatpak/stage/wpe-layer /workspace/flatpak_app /workspace/repo /workspace/fluxidc-linux-x86_64.flatpak'
}

prepare_wpe_layer() {
  local version
  version="${WPE_LAYER_VERSION:-$(tr -d '\r\n' < "${WPE_LAYER_VERSION_FILE}")}"
  local stage_dir="${PROJECT_ROOT}/flatpak/stage/wpe-layer"
  local repo
  repo="$(detect_github_repo)"
  local base_url="${WPE_LAYER_BASE_URL:-https://github.com/${repo}/releases/download/flatpak-wpe-layer-${version}}"

  mkdir -p "${stage_dir}"

  if [[ -n "${LOCAL_WPE_LAYER_ARCHIVE:-}" ]]; then
    echo "==> Using local WPE layer archive: ${LOCAL_WPE_LAYER_ARCHIVE}"
    cp "${LOCAL_WPE_LAYER_ARCHIVE}" "${stage_dir}/${WPE_LAYER_ASSET}"
    if [[ -f "${LOCAL_WPE_LAYER_ARCHIVE}.sha256" ]]; then
      cp "${LOCAL_WPE_LAYER_ARCHIVE}.sha256" "${stage_dir}/${WPE_LAYER_ASSET}.sha256"
    fi
  else
    echo "==> Downloading WPE layer ${version}"
    curl -fL "${base_url}/${WPE_LAYER_ASSET}" -o "${stage_dir}/${WPE_LAYER_ASSET}"
    curl -fL "${base_url}/${WPE_LAYER_ASSET}.sha256" -o "${stage_dir}/${WPE_LAYER_ASSET}.sha256"
  fi

  if [[ -f "${stage_dir}/${WPE_LAYER_ASSET}.sha256" ]]; then
    (
      cd "${stage_dir}"
      sha256sum -c "${WPE_LAYER_ASSET}.sha256"
    )
  fi
}

if [[ "${SKIP_PREPARE:-0}" != "1" ]]; then
  export PUB_CACHE="${PUB_CACHE:-${PROJECT_ROOT}/.pub-cache}"
  bash "${SCRIPT_DIR}/prepare_source_tree.sh"
fi

if [[ ! -f "${ARTIFACT_PATH}" ]]; then
  echo "missing Flatpak source tree artifact: ${ARTIFACT_PATH}" >&2
  exit 1
fi

echo "==> Extracting staged source tree"
cleanup_generated_artifacts
mkdir -p flatpak/stage/source-tree
tar -xzf "${ARTIFACT_PATH}" -C flatpak/stage/source-tree
prepare_wpe_layer

echo "==> Running Flatpak package build in ${CONTAINER_IMAGE}"
docker run --rm --privileged \
  -v "${PROJECT_ROOT}:/workspace" \
  -w /workspace \
  "${CONTAINER_IMAGE}" \
  bash -lc '
    set -euo pipefail
    flatpak --system remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    xvfb-run --auto-servernum flatpak-builder \
      --repo=repo \
      --disable-rofiles-fuse \
      --install-deps-from=flathub \
      --force-clean \
      --default-branch=stable \
      --arch=x86_64 \
      --ccache \
      --verbose \
      flatpak_app \
      flatpak/com.fdcflare.client.yml
    flatpak build-bundle repo fluxidc-linux-x86_64.flatpak com.fdcflare.client stable
  '

echo "Flatpak bundle ready:"
echo "  ${OUTPUT_BUNDLE}"
