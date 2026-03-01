#!/usr/bin/env bash
#
# validate-skills.sh — Verify skill files in both plugins meet conventions.
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

# --- Dockyard public skills ---
echo ""
echo "Dockyard public skills:"
DOCKYARD_SKILLS=(
  brownfield-analysis
  code-review
  review-and-submit
  observability
)

for skill in "${DOCKYARD_SKILLS[@]}"; do
  validate_skill \
    "$REPO_ROOT/plugins/dockyard/skills/$skill/SKILL.md" \
    "dockyard/$skill"
done

# --- Shipwright internal skills ---
echo ""
echo "Shipwright internal skills:"
SHIPWRIGHT_SKILLS=(
  tdd
  verification-before-completion
  systematic-debugging
  anti-rationalization
  decision-categorization
)

for skill in "${SHIPWRIGHT_SKILLS[@]}"; do
  validate_skill \
    "$REPO_ROOT/plugins/shipwright/internal/skills/$skill/SKILL.md" \
    "shipwright/$skill"
done

echo ""
TOTAL=$((PASS + FAIL))
echo "validate-skills: $PASS/$TOTAL passed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
