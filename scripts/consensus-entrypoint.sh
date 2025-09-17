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
    log "aria2c not found in PATH before install. Attempting installation.";
    if command -v apt-get >/dev/null 2>&1; then
      if [ "$(id -u)" != "0" ]; then
        err "Not running as root; cannot apt-get install aria2. Will fall back to curl.";
      else
        export DEBIAN_FRONTEND=noninteractive
        if ! apt-get update -y 2>&1 | sed 's/^/[snapshot-init][apt] /'; then
          err "apt-get update failed"; fi
        if ! apt-get install -y --no-install-recommends aria2 2>&1 | sed 's/^/[snapshot-init][apt] /'; then
          err "apt-get install aria2 failed"; fi
      fi
    else
      err "apt-get not available; cannot install aria2.";
    fi
  fi
  if command -v aria2c >/dev/null 2>&1; then
    log "aria2c detected: $(command -v aria2c)";
    if ! aria2c -x "${SNAPSHOT_ARIA2_CONN}" -s "${SNAPSHOT_ARIA2_SPLIT}" -k 4M --allow-overwrite=true --continue=true --summary-interval=15 -o "$(basename "${tmpfile}")" -d "$(dirname "${tmpfile}")" "${url}"; then
      err "aria2c download failed (exit $?). Falling back to curl."; downloader="curl"
    else
      log "Download complete via aria2c";
    fi
  else
    downloader="curl"
  fi
  if [ "${downloader}" = "curl" ]; then
    log "Using curl fallback";
    # Use --progress-bar if stderr is a TTY; otherwise just regular output
    CURL_PROGRESS_FLAG="--progress-bar"
    if [ ! -t 2 ]; then
      CURL_PROGRESS_FLAG=""
    fi
    log "curl fallback starting (progress may be limited in non-TTY).";
    # Print content length if available
    curl -sI "${url}" | awk '/[Cc]ontent-[Ll]ength/ {print "[snapshot-init] Reported size: "$2}' | tr -d '\r'
    if ! curl -L --fail --retry 5 --retry-delay 5 ${CURL_PROGRESS_FLAG} -o "${tmpfile}" "${url}"; then
      err "Failed to download snapshot from ${url}"; return 1; fi
  fi

  # Install file command if missing (needed for archive type detection)
  if ! command -v file >/dev/null 2>&1; then
    if [ "$(id -u)" = "0" ] && command -v apt-get >/dev/null 2>&1; then
      log "Installing file package for archive detection";
      apt-get install -y --no-install-recommends file >/dev/null 2>&1 || true
    fi
  fi

  # Detect type (tar, tar.gz, tar.lz4, tar.zst) - with fallback to filename
  local file_type=""
  if command -v file >/dev/null 2>&1; then
    file_type=$(file "${tmpfile}" 2>/dev/null || true)
  fi

  # Fallback: detect by URL extension if file command failed
  if [ -z "${file_type}" ]; then
    log "file command unavailable, using URL extension fallback";
    case "${url}" in
      *.tar.gz|*.tgz) file_type="gzip compressed" ;;
      *.tar.zst|*.tar.zstd) file_type="Zstandard compressed" ;;
      *.tar.lz4) file_type="LZ4 compressed" ;;
      *.tar) file_type="tar archive" ;;
      *) file_type="unknown" ;;
    esac
  fi

  if echo "${file_type}" | grep -qi 'tar archive'; then
    log "Extracting uncompressed tar archive";
    tar -xf "${tmpfile}" -C "${DATA_DIR}" || return 1
  elif echo "${file_type}" | grep -qi 'gzip compressed'; then
    log "Extracting gzip tar archive";
    tar -xzf "${tmpfile}" -C "${DATA_DIR}" || return 1
  elif echo "${file_type}" | grep -qi 'Zstandard compressed'; then
    if ! command -v zstd >/dev/null 2>&1; then
      log "Installing zstd";
      if [ "$(id -u)" = "0" ] && command -v apt-get >/dev/null 2>&1; then
        apt-get install -y --no-install-recommends zstd >/dev/null 2>&1 || true
      elif command -v apk >/dev/null 2>&1; then
        apk add --no-cache zstd >/dev/null 2>&1 || true
      fi
    fi
    tar -I zstd -xf "${tmpfile}" -C "${DATA_DIR}" || return 1
  elif echo "${file_type}" | grep -qi 'LZ4 compressed'; then
    if ! command -v lz4 >/dev/null 2>&1; then
      log "Installing lz4";
      if [ "$(id -u)" = "0" ] && command -v apt-get >/dev/null 2>&1; then
        apt-get install -y --no-install-recommends lz4 >/dev/null 2>&1 || true
      elif command -v apk >/dev/null 2>&1; then
        apk add --no-cache lz4 >/dev/null 2>&1 || true
      fi
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
    err "Unknown archive type for snapshot (detected: ${file_type}). Proceeding without extraction."; return 1
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
