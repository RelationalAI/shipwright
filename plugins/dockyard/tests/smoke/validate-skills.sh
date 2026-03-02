#!/usr/bin/env bash
#
# validate-skills.sh — Verify skill files in both plugins meet conventions.
# Uses directory discovery instead of hardcoded file lists.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
PASS=0
FAIL=0

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

validate_skill() {
  local filepath="$1"
  local label="$2"

  echo ""
  echo "$label:"

  if [ ! -s "$filepath" ]; then
    fail "$label is missing or empty"
    return
  fi
  pass "$label exists and is non-empty"

  # Has a title heading or YAML frontmatter
  if head -1 "$filepath" | grep -qE '^(#|---)'; then
    pass "$label has title heading or frontmatter"
  else
    fail "$label missing title heading or YAML frontmatter"
  fi

  if grep -qi 'superpowers:' "$filepath"; then
    fail "$label references superpowers: namespace"
  else
    pass "$label does not reference superpowers: namespace"
  fi

  if grep -q '\.planning/' "$filepath"; then
    fail "$label references .planning/ (GSD internal)"
  else
    pass "$label does not reference .planning/"
  fi
}

echo "=== validate-skills ==="

# --- Dockyard public skills (discover from directory) ---
echo ""
echo "Dockyard public skills:"
for skill_dir in "$REPO_ROOT"/plugins/dockyard/skills/*/; do
  skill_name=$(basename "$skill_dir")
  validate_skill "$skill_dir/SKILL.md" "dockyard/$skill_name"
done

# --- Shipwright internal skills (discover from directory) ---
echo ""
echo "Shipwright internal skills:"
for skill_dir in "$REPO_ROOT"/plugins/shipwright/internal/skills/*/; do
  skill_name=$(basename "$skill_dir")
  validate_skill "$skill_dir/SKILL.md" "shipwright/$skill_name"
done

echo ""
TOTAL=$((PASS + FAIL))
echo "validate-skills: $PASS/$TOTAL passed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
