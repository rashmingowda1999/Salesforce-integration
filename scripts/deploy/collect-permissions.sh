#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR=${1:-force-app}
DELTA_DIR=${2:-delta}

if [ ! -f "$DELTA_DIR/package.xml" ]; then
  echo "No package.xml in $DELTA_DIR; nothing to do" >&2
  exit 0
fi

# Extract object and field members from package.xml
mapfile -t MEMBERS < <(grep -oE '<members>[^<]+' "$DELTA_DIR/package.xml" | sed 's#<members>##' | sort -u)
if [ ${#MEMBERS[@]} -eq 0 ]; then
  echo "No members found in package.xml; skipping perms collection" >&2
  exit 0
fi

echo "Scanning profiles/permsets for: ${MEMBERS[*]}"

copy_if_matches() {
  local file="$1"
  local matched=false
  for m in "${MEMBERS[@]}"; do
    if grep -q "$m" "$file"; then
      matched=true
      break
    fi
  done
  if [ "$matched" = true ]; then
    local rel="${file#$SOURCE_DIR/}"
    local dest="$DELTA_DIR/$rel"
    mkdir -p "$(dirname "$dest")"
    cp "$file" "$dest"
    echo "Included $rel"
  fi
}

export -f copy_if_matches
export SOURCE_DIR DELTA_DIR MEMBERS

find "$SOURCE_DIR" \( -path "*/profiles/*.profile-meta.xml" -o -path "*/permissionsets/*.permissionset-meta.xml" \) -type f -print0 |
  xargs -0 -I{} bash -c 'copy_if_matches "$@"' _ {}
