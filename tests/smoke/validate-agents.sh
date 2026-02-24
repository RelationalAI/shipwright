#!/usr/bin/env bash
#
# validate-agents.sh — Verify agent files meet M1 conventions.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0

AGENTS=(
  triage.md
  implementer.md
  reviewer.md
  validator.md
  doc-digest.md
)

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

echo "=== validate-agents ==="

for agent in "${AGENTS[@]}"; do
  filepath="$REPO_ROOT/agents/$agent"
  echo ""
  echo "$agent:"

  # File exists and is not empty
  if [ ! -s "$filepath" ]; then
    fail "$agent is missing or empty"
    continue
  fi
  pass "$agent exists and is non-empty"

  # Contains a role description (first non-empty line after heading should describe the role)
  # We check for "You are" or "agent" as a proxy for role description
  if grep -qi 'you are\|agent' "$filepath"; then
    pass "$agent contains role description"
  else
    fail "$agent missing role description (expected 'You are' or 'agent')"
  fi

  # References at least one skill (except doc-digest which is self-contained)
  if [ "$agent" = "doc-digest.md" ]; then
    pass "$agent is self-contained (no skill injection expected)"
  else
    if grep -q 'skills/' "$filepath"; then
      pass "$agent references at least one skill"
    else
      fail "$agent does not reference any skill"
    fi
  fi

  # Contains output/return format section
  # Look for headings or sections about output, return, result
  if grep -qiE '## (Output|Return|Result|Returning)' "$filepath"; then
    pass "$agent contains output/return format section"
  else
    fail "$agent missing output/return format section (expected ## Output, ## Return, or ## Result heading)"
  fi
done

echo ""
TOTAL=$((PASS + FAIL))
echo "validate-agents: $PASS/$TOTAL passed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
