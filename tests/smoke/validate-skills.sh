#!/usr/bin/env bash
#
# validate-skills.sh — Verify skill files meet M1 conventions.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0

SKILLS=(
  tdd.md
  verification-before-completion.md
  systematic-debugging.md
  anti-rationalization.md
  decision-categorization.md
  brownfield-analysis.md
)

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

echo "=== validate-skills ==="

for skill in "${SKILLS[@]}"; do
  filepath="$REPO_ROOT/skills/$skill"
  echo ""
  echo "$skill:"

  # File exists and is not empty
  if [ ! -s "$filepath" ]; then
    fail "$skill is missing or empty"
    continue
  fi
  pass "$skill exists and is non-empty"

  # Contains attribution header
  if grep -q '> \*\*Attribution:\*\*' "$filepath"; then
    pass "$skill has attribution header"
  else
    fail "$skill missing attribution header (expected '> **Attribution:**')"
  fi

  # No references to superpowers: namespace
  if grep -qi 'superpowers:' "$filepath"; then
    fail "$skill references superpowers: namespace"
  else
    pass "$skill does not reference superpowers: namespace"
  fi

  # No references to .planning/ (GSD internal)
  if grep -q '\.planning/' "$filepath"; then
    fail "$skill references .planning/ (GSD internal)"
  else
    pass "$skill does not reference .planning/"
  fi
done

echo ""
TOTAL=$((PASS + FAIL))
echo "validate-skills: $PASS/$TOTAL passed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
