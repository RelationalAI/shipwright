#!/usr/bin/env bash
#
# validate-commands.sh — Verify command files in both plugins meet conventions.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
PASS=0
FAIL=0

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

validate_command() {
  local plugin="$1"
  local cmd="$2"
  local filepath="$REPO_ROOT/plugins/$plugin/commands/$cmd"
  local label="$plugin/$cmd"

  echo ""
  echo "$label:"

  # File exists and is not empty
  if [ ! -s "$filepath" ]; then
    fail "$label is missing or empty"
    return
  fi
  pass "$label exists and is non-empty"

  # Contains YAML frontmatter (starts with ---)
  if head -1 "$filepath" | grep -q '^---'; then
    pass "$label has YAML frontmatter opening"
  else
    fail "$label missing YAML frontmatter (first line should be '---')"
  fi

  # Contains description: in frontmatter (between first and second ---)
  frontmatter=$(awk 'NR==1 && /^---$/{found=1; next} found && /^---$/{exit} found{print}' "$filepath" | head -20)
  if echo "$frontmatter" | grep -q 'description:'; then
    pass "$label has description: in frontmatter"
  else
    fail "$label missing description: in frontmatter"
  fi

  # Has content beyond frontmatter
  body_lines=$(sed '1,/^---$/{ /^---$/!d; }' "$filepath" | sed '1d' | grep -c '[^[:space:]]' || true)
  if [ "$body_lines" -gt 0 ]; then
    pass "$label has content beyond frontmatter"
  else
    fail "$label is empty beyond frontmatter"
  fi
}

echo "=== validate-commands ==="

# --- Dockyard commands ---
echo ""
echo "Dockyard commands:"
DOCKYARD_COMMANDS=(
  codebase-analyze.md
  code-review.md
  doc-digest.md
  investigate.md
  observe.md
  review-and-submit.md
  feedback.md
)

for cmd in "${DOCKYARD_COMMANDS[@]}"; do
  validate_command "dockyard" "$cmd"
done

# --- Shipwright commands ---
echo ""
echo "Shipwright commands:"
SHIPWRIGHT_COMMANDS=(
  shipwright.md
  feedback.md
)

for cmd in "${SHIPWRIGHT_COMMANDS[@]}"; do
  validate_command "shipwright" "$cmd"
done

echo ""
TOTAL=$((PASS + FAIL))
echo "validate-commands: $PASS/$TOTAL passed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
