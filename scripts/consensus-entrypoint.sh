#!/usr/bin/env bash
set -euo pipefail

# This script wraps the nitro consensus client. If the data directory is empty
# and SNAPSHOT_URL is set, it will download and extract the snapshot before
# starting the client. A marker file is used so we only attempt once.

DATA_DIR="/home/user/.arbitrum"
MARKER_FILE="${DATA_DIR}/.snapshot_restored"
SNAPSHOT_URL="${SNAPSHOT_URL:-}" # allow empty
SNAPSHOT_ARIA2_CONN=16
SNAPSHOT_ARIA2_SPLIT=16

log() { printf '[snapshot-init] %s\n' "$*"; }
err() { printf '[snapshot-init][error] %s\n' "$*" >&2; }

download_and_extract() {
  local url="$1"
  local tmpfile
  tmpfile=$(mktemp -d)/snapshot

  log "Downloading snapshot: ${url}";
  local downloader="aria2c"
  if ! command -v aria2c >/dev/null 2>&1; then
    # Try apt-get (Debian/Ubuntu based) first
    if command -v apt-get >/dev/null 2>&1; then
      log "Installing aria2 via apt-get";
      export DEBIAN_FRONTEND=noninteractive
      apt-get update -y >/dev/null 2>&1 || true
      apt-get install -y --no-install-recommends aria2 >/dev/null 2>&1 || true
    fi
  fi
  if command -v aria2c >/dev/null 2>&1; then
    if ! aria2c -x "${SNAPSHOT_ARIA2_CONN}" -s "${SNAPSHOT_ARIA2_SPLIT}" -k 4M --allow-overwrite=true --continue=true -o "$(basename "${tmpfile}")" -d "$(dirname "${tmpfile}")" "${url}"; then
      err "aria2c failed, falling back to curl"; downloader="curl"
    else
      log "Download complete via aria2c";
    fi
  else
    downloader="curl"
  fi
  if [ "${downloader}" = "curl" ]; then
    log "Using curl fallback";
    if ! curl -L --fail --retry 5 --retry-delay 5 -o "${tmpfile}" "${url}"; then
      err "Failed to download snapshot from ${url}"; return 1; fi
  fi

  # Detect type (tar, tar.gz, tar.lz4, tar.zst)
  # We expect an archive containing the contents of the data dir.
  if file "${tmpfile}" | grep -qi 'tar archive'; then
    log "Extracting uncompressed tar archive";
    tar -xf "${tmpfile}" -C "${DATA_DIR}" || return 1
  elif file "${tmpfile}" | grep -qi 'gzip compressed'; then
    log "Extracting gzip tar archive";
    tar -xzf "${tmpfile}" -C "${DATA_DIR}" || return 1
  elif file "${tmpfile}" | grep -qi 'Zstandard compressed'; then
    if ! command -v zstd >/dev/null 2>&1; then
      log "Installing zstd (busybox/apk if available)";
      if command -v apk >/dev/null 2>&1; then apk add --no-cache zstd || true; fi
    fi
    tar -I zstd -xf "${tmpfile}" -C "${DATA_DIR}" || return 1
  elif file "${tmpfile}" | grep -qi 'LZ4 compressed'; then
    if ! command -v lz4 >/dev/null 2>&1; then
      log "Installing lz4 (busybox/apk if available)";
      if command -v apk >/dev/null 2>&1; then apk add --no-cache lz4 || true; fi
    fi
    # lz4 may produce a .tar when decompressed if it's a .tar.lz4
    mkdir -p "${DATA_DIR}/.tmp_extract"
    if lz4 -d "${tmpfile}" -c > "${DATA_DIR}/.tmp_extract/archive.tar"; then
      tar -xf "${DATA_DIR}/.tmp_extract/archive.tar" -C "${DATA_DIR}" || return 1
      rm -rf "${DATA_DIR}/.tmp_extract"
    else
      err "Failed to decompress lz4 archive"; return 1
    fi
  else
    err "Unknown archive type for snapshot. Proceeding without extraction."; return 1
  fi

  touch "${MARKER_FILE}"
  log "Snapshot restored."
}

# Ensure data dir exists
mkdir -p "${DATA_DIR}"

# Always restore snapshot if URL is provided and marker file not present
if [ -n "${SNAPSHOT_URL}" ] && [ ! -f "${MARKER_FILE}" ]; then
  log "Marker file missing; restoring snapshot from ${SNAPSHOT_URL}";
  if ! download_and_extract "${SNAPSHOT_URL}"; then
    err "Snapshot restore failed; continuing with genesis sync.";
  fi
else
  log "No snapshot restoration needed (either marker exists or SNAPSHOT_URL unset).";
fi

log "Starting nitro consensus client.";
exec "$@"
