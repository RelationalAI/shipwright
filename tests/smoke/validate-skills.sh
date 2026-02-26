#!/usr/bin/env bash
#
# validate-skills.sh — Verify skill files meet M1 conventions.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0

USER_SKILLS=(
  brownfield-analysis
  code-review
  submit
)

# Original Shipwright skills (no external attribution required)
ORIGINAL_SKILLS=(code-review submit)

is_original() {
  local skill="$1"
  for s in "${ORIGINAL_SKILLS[@]}"; do
    if [ "$s" = "$skill" ]; then return 0; fi
  done
  return 1
}

INTERNAL_SKILLS=(
  tdd
  verification-before-completion
  systematic-debugging
  anti-rationalization
  decision-categorization
)

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

echo "=== validate-skills ==="

# Validate user-facing skills
echo ""
echo "User-facing skills:"
for skill in "${USER_SKILLS[@]}"; do
  filepath="$REPO_ROOT/skills/$skill/SKILL.md"

  echo ""
  echo "$skill:"

  if [ ! -s "$filepath" ]; then
    fail "$skill is missing or empty"
    continue
  fi
  pass "$skill exists and is non-empty"

  # Contains attribution header (skip for original skills)
  if is_original "$skill"; then
    pass "$skill is original (no attribution required)"
  elif grep -q '> \*\*Attribution:\*\*' "$filepath"; then
    pass "$skill has attribution header"
  else
    fail "$skill missing attribution header (expected '> **Attribution:**')"
  fi

  if grep -qi 'superpowers:' "$filepath"; then
    fail "$skill references superpowers: namespace"
  else
    pass "$skill does not reference superpowers: namespace"
  fi

  if grep -q '\.planning/' "$filepath"; then
    fail "$skill references .planning/ (GSD internal)"
  else
    pass "$skill does not reference .planning/"
  fi
done

# Validate internal skills
echo ""
echo "Internal skills:"
for skill in "${INTERNAL_SKILLS[@]}"; do
  filepath="$REPO_ROOT/internal/skills/$skill/SKILL.md"
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
