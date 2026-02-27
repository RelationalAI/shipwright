#!/usr/bin/env bash
#
# check-dockyard.sh — Verify the dockyard plugin is installed before allowing
#                      shipwright to start. Exits 2 (hard-block) if missing.
#
set -euo pipefail

REGISTRY="$HOME/.claude/plugins/installed_plugins.json"

if [ ! -f "$REGISTRY" ]; then
  echo "ERROR: Shipwright requires the 'dockyard' plugin."
  echo "Install it with: /plugin install dockyard@shipwright-marketplace"
  exit 2
fi

if ! grep -q '"dockyard@' "$REGISTRY" 2>/dev/null; then
  echo "ERROR: Shipwright requires the 'dockyard' plugin."
  echo "Install it with: /plugin install dockyard@shipwright-marketplace"
  exit 2
fi
