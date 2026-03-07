#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/utils.sh"

ensure_dirs

log "Generating delta package using sfdx-git-delta (sgd)..."

# Use npx sfdx-git-delta to create a metadata package in tmp_delta
# Falls back to globally installed 'sfdx-git-delta' if available
if command -v npx >/dev/null 2>&1; then
  npx sfdx-git-delta --to HEAD --output "$TMP_DIR" || true
else
  sfdx-git-delta --to HEAD --output "$TMP_DIR" || true
fi

# Remove managed package components from package.xml (entries with a namespace or colon)
if [ -f "$TMP_DIR/package.xml" ]; then
  log "Filtering managed-package components out of package.xml"
  xmlstarlet tr - > "$TMP_DIR/package.filtered.xml" <<'XSL'
  <xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
    <xsl:output method="xml" indent="yes"/>
    <xsl:template match="node()|@*">
      <xsl:copy>
        <xsl:apply-templates select="node()|@*"/>
      </xsl:copy>
    </xsl:template>
    <xsl:template match="*/*[name()='members' and contains(text(), ':')]"/>
  </xsl:stylesheet>
XSL
  mv "$TMP_DIR/package.filtered.xml" "$TMP_DIR/package.xml" || true
fi

# Detect Apex class changes
if git diff --name-only HEAD~1 HEAD | grep -E "classes/.*\.cls$" >/dev/null 2>&1; then
  log "Apex classes changed"
  export APEX_CHANGED=true
  echo "Apex classes changed" > "$TMP_DIR/apex_changed.flag"
else
  export APEX_CHANGED=false
fi

log "Delta generation complete. Output: $TMP_DIR"
