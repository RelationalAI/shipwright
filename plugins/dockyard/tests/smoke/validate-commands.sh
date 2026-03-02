#!/usr/bin/env bash
#
# validate-commands.sh — Verify command files in both plugins meet conventions.
# Uses directory discovery instead of hardcoded file lists.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
PASS=0
FAIL=0

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

validate_command() {
  local plugin="$1"
  local filepath="$2"
  local cmd_name
  cmd_name=$(basename "$filepath")
  local label="$plugin/$cmd_name"

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

# --- Dockyard commands (discover from directory) ---
echo ""
echo "Dockyard commands:"
for cmd_file in "$REPO_ROOT"/plugins/dockyard/commands/*.md; do
  [ -f "$cmd_file" ] || continue
  validate_command "dockyard" "$cmd_file"
done

# --- Shipwright commands (discover from directory) ---
echo ""
echo "Shipwright commands:"
for cmd_file in "$REPO_ROOT"/plugins/shipwright/commands/*.md; do
  [ -f "$cmd_file" ] || continue
  validate_command "shipwright" "$cmd_file"
done

# --- Cross-reference: knowledge file paths in observability commands ---
echo ""
echo "Knowledge file cross-references:"
DOCKYARD="$REPO_ROOT/plugins/dockyard"
for cmd in "$DOCKYARD"/commands/investigate.md "$DOCKYARD"/commands/observe.md; do
  [ -f "$cmd" ] || continue
  cmd_name=$(basename "$cmd")
  while IFS= read -r ref_path; do
    full_path="$DOCKYARD/$ref_path"
    if [ -s "$full_path" ]; then
      pass "$cmd_name references $ref_path (exists)"
    else
      fail "$cmd_name references $ref_path (NOT FOUND)"
    fi
  done < <(grep -oE 'skills/observability/knowledge/[a-z/-]+\.md' "$cmd" | sort -u)
done

echo ""
TOTAL=$((PASS + FAIL))
echo "validate-commands: $PASS/$TOTAL passed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
