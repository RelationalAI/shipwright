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

  # Contains a role description (starts with "You are" somewhere in the file)
  if grep -qi '^you are\|^- you are' "$filepath"; then
    pass "$label contains role description"
  else
    fail "$label missing role description (expected line starting with 'You are')"
  fi

  # References skills (if expected)
  if [ "$expect_skills" = "yes" ]; then
    if grep -qE 'skills/|dockyard:' "$filepath"; then
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
echo "  (none currently)"

validate_agent \
  "$REPO_ROOT/plugins/dockyard/agents/code-reviewer.md" \
  "dockyard/code-reviewer.md" \
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

# --- Cross-plugin reference validation ---
echo ""
echo "Cross-plugin references:"
# Verify that dockyard:X references resolve to actual dockyard skills, agents, or commands
SCAN_FILES=(
  "$REPO_ROOT/plugins/shipwright/internal/agents/"*.md
  "$REPO_ROOT/plugins/shipwright/commands/shipwright.md"
  "$REPO_ROOT/plugins/dockyard/skills/"*/SKILL.md
)
for file in "${SCAN_FILES[@]}"; do
  [ -f "$file" ] || continue
  refs=$(grep -oE 'dockyard:[a-z-]+' "$file" 2>/dev/null | sort -u || true)
  for ref in $refs; do
    name="${ref#dockyard:}"
    skill_path="$REPO_ROOT/plugins/dockyard/skills/$name/SKILL.md"
    agent_path="$REPO_ROOT/plugins/dockyard/agents/$name.md"
    command_path="$REPO_ROOT/plugins/dockyard/commands/$name.md"
    label="$(basename "$file"):$ref"
    if [ -f "$skill_path" ] || [ -f "$agent_path" ] || [ -f "$command_path" ]; then
      pass "$label resolves"
    else
      fail "$label does not resolve (expected skill, agent, or command named '$name')"
    fi
  done
done

echo ""
TOTAL=$((PASS + FAIL))
echo "validate-agents: $PASS/$TOTAL passed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
