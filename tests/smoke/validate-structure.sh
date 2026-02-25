#!/usr/bin/env bash
#
# validate-structure.sh — Verify all M1 plugin files exist.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0

check() {
  local label="$1"
  local path="$2"
  if [ -e "$path" ]; then
    echo "  PASS  $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $label  (missing: $path)"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== validate-structure ==="

# --- Skills (6) ---
echo ""
echo "Skills:"
check "skills/tdd/SKILL.md"                        "$REPO_ROOT/skills/tdd/SKILL.md"
check "skills/verification-before-completion/SKILL.md" "$REPO_ROOT/skills/verification-before-completion/SKILL.md"
check "skills/systematic-debugging/SKILL.md"       "$REPO_ROOT/skills/systematic-debugging/SKILL.md"
check "skills/anti-rationalization/SKILL.md"       "$REPO_ROOT/skills/anti-rationalization/SKILL.md"
check "skills/decision-categorization/SKILL.md"    "$REPO_ROOT/skills/decision-categorization/SKILL.md"
check "skills/brownfield-analysis/SKILL.md"        "$REPO_ROOT/skills/brownfield-analysis/SKILL.md"

# --- Agents (5) ---
echo ""
echo "Agents:"
check "agents/triage.md"       "$REPO_ROOT/agents/triage.md"
check "agents/implementer.md"  "$REPO_ROOT/agents/implementer.md"
check "agents/reviewer.md"     "$REPO_ROOT/agents/reviewer.md"
check "agents/validator.md"    "$REPO_ROOT/agents/validator.md"
check "agents/doc-digest.md"   "$REPO_ROOT/agents/doc-digest.md"

# --- Commands (5) ---
echo ""
echo "Commands:"
check "commands/shipwright.md"                "$REPO_ROOT/commands/shipwright.md"
check "commands/shipwright-codebase-analyze.md" "$REPO_ROOT/commands/shipwright-codebase-analyze.md"
check "commands/shipwright-doc-digest.md"     "$REPO_ROOT/commands/shipwright-doc-digest.md"
check "commands/shipwright-debug.md"          "$REPO_ROOT/commands/shipwright-debug.md"
check "commands/shipwright-report.md"         "$REPO_ROOT/commands/shipwright-report.md"

# --- plugin.json ---
echo ""
echo "Plugin manifest:"
check "plugin.json exists" "$REPO_ROOT/.claude-plugin/plugin.json"

# Validate plugin.json has required keys
if [ -f "$REPO_ROOT/.claude-plugin/plugin.json" ]; then
  for key in name description version author; do
    if grep -q "\"$key\"" "$REPO_ROOT/.claude-plugin/plugin.json"; then
      echo "  PASS  plugin.json contains \"$key\""
      PASS=$((PASS + 1))
    else
      echo "  FAIL  plugin.json missing \"$key\""
      FAIL=$((FAIL + 1))
    fi
  done
else
  echo "  SKIP  plugin.json key checks (file missing)"
  FAIL=$((FAIL + 6))
fi

# --- .gitignore includes .workflow/ ---
echo ""
echo "Gitignore:"
if [ -f "$REPO_ROOT/.gitignore" ] && grep -q '\.workflow/' "$REPO_ROOT/.gitignore"; then
  echo "  PASS  .gitignore includes .workflow/"
  PASS=$((PASS + 1))
else
  echo "  FAIL  .gitignore missing .workflow/ entry"
  FAIL=$((FAIL + 1))
fi

# --- README.md ---
echo ""
echo "Docs:"
check "README.md" "$REPO_ROOT/README.md"

# --- Summary ---
echo ""
TOTAL=$((PASS + FAIL))
echo "validate-structure: $PASS/$TOTAL passed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
