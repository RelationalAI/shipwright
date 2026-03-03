#!/usr/bin/env bash
#
# setup-githooks.sh — Ensure git uses .githooks/ for hook scripts.
# Called by Claude Code SessionStart hook.
#
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0

CURRENT=$(git config core.hooksPath 2>/dev/null || echo "")
if [ "$CURRENT" != ".githooks" ]; then
  git config core.hooksPath .githooks
fi
