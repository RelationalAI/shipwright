#!/usr/bin/env bash
#
# validate-commands.sh — Verify command files meet M1 conventions.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0

COMMANDS=(
  shipwright.md
  codebase-analyze.md
  doc-digest.md
  debug.md
  report.md
)

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

echo "=== validate-commands ==="

for cmd in "${COMMANDS[@]}"; do
  filepath="$REPO_ROOT/commands/$cmd"
  echo ""
  echo "$cmd:"

  # File exists and is not empty
  if [ ! -s "$filepath" ]; then
    fail "$cmd is missing or empty"
    continue
  fi
  pass "$cmd exists and is non-empty"

  # Contains YAML frontmatter (starts with ---)
  if head -1 "$filepath" | grep -q '^---'; then
    pass "$cmd has YAML frontmatter opening"
  else
    fail "$cmd missing YAML frontmatter (first line should be '---')"
  fi

  # Contains description: in frontmatter
  # Extract frontmatter (between first and second ---) and check for description:
  frontmatter=$(sed -n '1,/^---$/{ /^---$/d; p; }' "$filepath" | head -20)
  if echo "$frontmatter" | grep -q 'description:'; then
    pass "$cmd has description: in frontmatter"
  else
    fail "$cmd missing description: in frontmatter"
  fi

  # Has content beyond frontmatter
  # Count lines after the closing --- of frontmatter
  body_lines=$(sed '1,/^---$/{ /^---$/!d; }' "$filepath" | sed '1d' | grep -c '[^[:space:]]' || true)
  if [ "$body_lines" -gt 0 ]; then
    pass "$cmd has content beyond frontmatter"
  else
    fail "$cmd is empty beyond frontmatter"
  fi
done

echo ""
TOTAL=$((PASS + FAIL))
echo "validate-commands: $PASS/$TOTAL passed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
