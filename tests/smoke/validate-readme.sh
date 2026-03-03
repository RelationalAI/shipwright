#!/usr/bin/env bash
#
# validate-readme.sh — Verify every public command and skill has a README entry.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
README="$REPO_ROOT/README.md"
PASS=0
FAIL=0

echo "=== validate-readme ==="

if [ ! -f "$README" ]; then
  echo "  FAIL  README.md not found"
  exit 1
fi

# --- Check all public commands are listed ---
echo ""
echo "Commands in README:"
for cmd_file in "$REPO_ROOT"/plugins/*/commands/*.md; do
  [ -f "$cmd_file" ] || continue
  plugin=$(echo "$cmd_file" | sed "s|.*/plugins/||" | cut -d/ -f1)
  cmd=$(basename "$cmd_file" .md)
  if grep -q "/$plugin:$cmd" "$README"; then
    echo "  PASS  /$plugin:$cmd"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  /$plugin:$cmd not found in README"
    FAIL=$((FAIL + 1))
  fi
done

# --- Check all public skills are listed ---
echo ""
echo "Skills in README:"
for skill_dir in "$REPO_ROOT"/plugins/*/skills/*/; do
  [ -d "$skill_dir" ] || continue
  # Skip internal skills
  echo "$skill_dir" | grep -q '/internal/' && continue
  [ -f "$skill_dir/SKILL.md" ] || continue
  skill=$(basename "$skill_dir")
  if grep -q "$skill" "$README"; then
    echo "  PASS  $skill"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $skill not found in README"
    FAIL=$((FAIL + 1))
  fi
done

# --- Summary ---
echo ""
TOTAL=$((PASS + FAIL))
echo "validate-readme: $PASS/$TOTAL passed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
