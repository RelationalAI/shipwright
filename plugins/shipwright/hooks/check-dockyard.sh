#!/bin/bash
REGISTRY="$HOME/.claude/plugins/installed_plugins.json"

if [ ! -f "$REGISTRY" ]; then
  echo "ERROR: Shipwright requires the 'dockyard' plugin."
  echo "Install it with: /plugin install dockyard@shipwright-marketplace"
  exit 2
fi

if ! jq -e '.plugins | keys[] | select(startswith("dockyard@"))' "$REGISTRY" > /dev/null 2>&1; then
  echo "ERROR: Shipwright requires the 'dockyard' plugin."
  echo "Install it with: /plugin install dockyard@shipwright-marketplace"
  exit 2
fi
