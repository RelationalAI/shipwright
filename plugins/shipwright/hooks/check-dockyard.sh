#!/bin/bash
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
