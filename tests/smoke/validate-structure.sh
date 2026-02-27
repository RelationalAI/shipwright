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

# --- User-facing skills (3) ---
echo ""
echo "User-facing skills:"
check "skills/brownfield-analysis/SKILL.md"        "$REPO_ROOT/skills/brownfield-analysis/SKILL.md"
check "skills/code-review/SKILL.md"                         "$REPO_ROOT/skills/code-review/SKILL.md"
check "skills/code-review/references/output-schema.md"      "$REPO_ROOT/skills/code-review/references/output-schema.md"
check "skills/review-and-submit/SKILL.md"                   "$REPO_ROOT/skills/review-and-submit/SKILL.md"

# --- Internal skills (5) ---
echo ""
echo "Internal skills:"
check "internal/skills/tdd/SKILL.md"                        "$REPO_ROOT/internal/skills/tdd/SKILL.md"
check "internal/skills/verification-before-completion/SKILL.md" "$REPO_ROOT/internal/skills/verification-before-completion/SKILL.md"
check "internal/skills/systematic-debugging/SKILL.md"       "$REPO_ROOT/internal/skills/systematic-debugging/SKILL.md"
check "internal/skills/anti-rationalization/SKILL.md"       "$REPO_ROOT/internal/skills/anti-rationalization/SKILL.md"
check "internal/skills/decision-categorization/SKILL.md"    "$REPO_ROOT/internal/skills/decision-categorization/SKILL.md"

# --- User-facing agents (1) ---
echo ""
echo "User-facing agents:"
check "agents/doc-digest.md"   "$REPO_ROOT/agents/doc-digest.md"

# --- Internal agents (4) ---
echo ""
echo "Internal agents:"
check "internal/agents/triage.md"       "$REPO_ROOT/internal/agents/triage.md"
check "internal/agents/implementer.md"  "$REPO_ROOT/internal/agents/implementer.md"
check "internal/agents/reviewer.md"     "$REPO_ROOT/internal/agents/reviewer.md"
check "internal/agents/validator.md"    "$REPO_ROOT/internal/agents/validator.md"

# --- Commands (5) ---
echo ""
echo "Commands:"
check "commands/shipwright.md"        "$REPO_ROOT/commands/shipwright.md"
check "commands/codebase-analyze.md" "$REPO_ROOT/commands/codebase-analyze.md"
check "commands/doc-digest.md"       "$REPO_ROOT/commands/doc-digest.md"
check "commands/debug.md"            "$REPO_ROOT/commands/debug.md"
check "commands/report.md"           "$REPO_ROOT/commands/report.md"

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
