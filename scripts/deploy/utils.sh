#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TMP_DIR="$ROOT_DIR/tmp_delta"
BACKUP_DIR="$ROOT_DIR/backup"

ensure_dirs() {
  mkdir -p "$TMP_DIR"
  mkdir -p "$BACKUP_DIR"
}

log() { echo "[deploy] $*"; }

is_managed() {
  # naive check: namespace token (e.g. ns__) in path or metadata fullName with ':'
  grep -qE '__|:' || return 1
}
