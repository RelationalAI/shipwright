#!/usr/bin/env bash
#
# validate-agents.sh — Verify agent files in both plugins meet conventions.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
PASS=0
FAIL=0

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

validate_agent() {
  local filepath="$1"
  local label="$2"
  local expect_skills="$3"  # "yes" or "no"

  echo ""
  echo "$label:"

  if [ ! -s "$filepath" ]; then
    fail "$label is missing or empty"
    return
  fi
  pass "$label exists and is non-empty"

  # Contains a role description
  if grep -qi 'you are\|agent' "$filepath"; then
    pass "$label contains role description"
  else
    fail "$label missing role description (expected 'You are' or 'agent')"
  fi

  # References skills (if expected)
  if [ "$expect_skills" = "yes" ]; then
    if grep -q 'skills/' "$filepath"; then
      pass "$label references at least one skill"
    else
      fail "$label does not reference any skill"
    fi
  else
    pass "$label is self-contained (no skill injection expected)"
  fi

  # Contains output/return format section
  if grep -qiE '## (Output|Return|Result|Returning)' "$filepath"; then
    pass "$label contains output/return format section"
  else
    fail "$label missing output/return format section (expected ## Output, ## Return, or ## Result heading)"
  fi
}

echo "=== validate-agents ==="

# --- Dockyard public agents ---
echo ""
echo "Dockyard public agents:"
validate_agent \
  "$REPO_ROOT/plugins/dockyard/agents/doc-digest.md" \
  "dockyard/doc-digest.md" \
  "no"

# --- Shipwright internal agents ---
echo ""
echo "Shipwright internal agents:"
SHIPWRIGHT_AGENTS=(
  triage.md
  implementer.md
  reviewer.md
  validator.md
)

for agent in "${SHIPWRIGHT_AGENTS[@]}"; do
  validate_agent \
    "$REPO_ROOT/plugins/shipwright/internal/agents/$agent" \
    "shipwright/$agent" \
    "yes"
done

echo ""
TOTAL=$((PASS + FAIL))
echo "validate-agents: $PASS/$TOTAL passed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
