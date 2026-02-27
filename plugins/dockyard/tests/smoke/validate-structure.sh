#!/usr/bin/env bash
#
# validate-structure.sh — Verify marketplace and plugin structure files exist.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
DOCKYARD="$REPO_ROOT/plugins/dockyard"
SHIPWRIGHT="$REPO_ROOT/plugins/shipwright"
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

# --- Marketplace-level files ---
echo ""
echo "Marketplace-level files:"
check "marketplace.json"          "$REPO_ROOT/.claude-plugin/marketplace.json"
check "CODEOWNERS"                "$REPO_ROOT/CODEOWNERS"
check "CONTRIBUTING.md"           "$REPO_ROOT/CONTRIBUTING.md"
check "README.md"                 "$REPO_ROOT/README.md"
check "THIRD_PARTY_NOTICES"       "$REPO_ROOT/THIRD_PARTY_NOTICES"
check "templates/SKILL_TEMPLATE.md"  "$REPO_ROOT/templates/SKILL_TEMPLATE.md"
check "templates/AGENT_TEMPLATE.md"  "$REPO_ROOT/templates/AGENT_TEMPLATE.md"

# --- Dockyard plugin ---
echo ""
echo "Dockyard plugin structure:"
check "dockyard/plugin.json"      "$DOCKYARD/.claude-plugin/plugin.json"

# Dockyard skills
check "dockyard/skills/brownfield-analysis/SKILL.md"  "$DOCKYARD/skills/brownfield-analysis/SKILL.md"
check "dockyard/skills/code-review/SKILL.md"           "$DOCKYARD/skills/code-review/SKILL.md"
check "dockyard/skills/review-and-submit/SKILL.md"     "$DOCKYARD/skills/review-and-submit/SKILL.md"
check "dockyard/skills/observability/SKILL.md"         "$DOCKYARD/skills/observability/SKILL.md"

# Dockyard agents
check "dockyard/agents/doc-digest.md"  "$DOCKYARD/agents/doc-digest.md"

# Dockyard commands
check "dockyard/commands/codebase-analyze.md"  "$DOCKYARD/commands/codebase-analyze.md"
check "dockyard/commands/doc-digest.md"        "$DOCKYARD/commands/doc-digest.md"
check "dockyard/commands/investigate.md"          "$DOCKYARD/commands/investigate.md"
check "dockyard/commands/code-review.md"             "$DOCKYARD/commands/code-review.md"
check "dockyard/commands/review-and-submit.md"   "$DOCKYARD/commands/review-and-submit.md"
check "dockyard/commands/feedback.md"            "$DOCKYARD/commands/feedback.md"

# --- Shipwright plugin ---
echo ""
echo "Shipwright plugin structure:"
check "shipwright/plugin.json"    "$SHIPWRIGHT/.claude-plugin/plugin.json"

# Shipwright hooks
check "shipwright/hooks/hooks.json"        "$SHIPWRIGHT/hooks/hooks.json"
check "shipwright/hooks/check-dockyard.sh" "$SHIPWRIGHT/hooks/check-dockyard.sh"

# Shipwright commands
check "shipwright/commands/shipwright.md"  "$SHIPWRIGHT/commands/shipwright.md"
check "shipwright/commands/feedback.md"    "$SHIPWRIGHT/commands/feedback.md"

# Shipwright internal agents
check "shipwright/internal/agents/triage.md"       "$SHIPWRIGHT/internal/agents/triage.md"
check "shipwright/internal/agents/implementer.md"  "$SHIPWRIGHT/internal/agents/implementer.md"
check "shipwright/internal/agents/reviewer.md"     "$SHIPWRIGHT/internal/agents/reviewer.md"
check "shipwright/internal/agents/validator.md"    "$SHIPWRIGHT/internal/agents/validator.md"

# Shipwright internal skills
check "shipwright/internal/skills/tdd/SKILL.md"                        "$SHIPWRIGHT/internal/skills/tdd/SKILL.md"
check "shipwright/internal/skills/verification-before-completion/SKILL.md" "$SHIPWRIGHT/internal/skills/verification-before-completion/SKILL.md"
check "shipwright/internal/skills/systematic-debugging/SKILL.md"       "$SHIPWRIGHT/internal/skills/systematic-debugging/SKILL.md"
check "shipwright/internal/skills/anti-rationalization/SKILL.md"       "$SHIPWRIGHT/internal/skills/anti-rationalization/SKILL.md"
check "shipwright/internal/skills/decision-categorization/SKILL.md"    "$SHIPWRIGHT/internal/skills/decision-categorization/SKILL.md"

# --- Validate marketplace.json has required keys ---
echo ""
echo "Marketplace manifest validation:"
if [ -f "$REPO_ROOT/.claude-plugin/marketplace.json" ]; then
  for key in name description plugins; do
    # Match root-level keys (no leading whitespace before the key)
    if grep -qE "^  \"$key\"" "$REPO_ROOT/.claude-plugin/marketplace.json"; then
      echo "  PASS  marketplace.json contains root-level \"$key\""
      PASS=$((PASS + 1))
    else
      echo "  FAIL  marketplace.json missing root-level \"$key\""
      FAIL=$((FAIL + 1))
    fi
  done
else
  echo "  SKIP  marketplace.json key checks (file missing)"
  FAIL=$((FAIL + 3))
fi

# --- Validate each plugin.json has required keys ---
echo ""
echo "Plugin manifest validation:"
for plugin_name in dockyard shipwright; do
  plugin_json="$REPO_ROOT/plugins/$plugin_name/.claude-plugin/plugin.json"
  if [ -f "$plugin_json" ]; then
    for key in name description version; do
      if grep -qE "^  \"$key\"" "$plugin_json"; then
        echo "  PASS  $plugin_name/plugin.json contains \"$key\""
        PASS=$((PASS + 1))
      else
        echo "  FAIL  $plugin_name/plugin.json missing \"$key\""
        FAIL=$((FAIL + 1))
      fi
    done
  else
    echo "  SKIP  $plugin_name/plugin.json key checks (file missing)"
    FAIL=$((FAIL + 3))
  fi
done

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

# --- Validate hooks.json content ---
echo ""
echo "Hooks validation:"
if [ -f "$SHIPWRIGHT/hooks/hooks.json" ]; then
  if grep -q '"SessionStart"' "$SHIPWRIGHT/hooks/hooks.json" && \
     grep -q 'check-dockyard.sh' "$SHIPWRIGHT/hooks/hooks.json"; then
    echo "  PASS  hooks.json references SessionStart and check-dockyard.sh"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  hooks.json missing SessionStart hook or check-dockyard.sh reference"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  SKIP  hooks.json content check (file missing)"
  FAIL=$((FAIL + 1))
fi

# --- Validate check-dockyard.sh behavior ---
echo ""
echo "Hook script behavior:"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# Test 1: No registry file — should exit 2
rc=0; HOME="$tmpdir" bash "$SHIPWRIGHT/hooks/check-dockyard.sh" >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 2 ]; then
  echo "  PASS  check-dockyard.sh exits 2 when registry missing"
  PASS=$((PASS + 1))
else
  echo "  FAIL  check-dockyard.sh should exit 2 when registry missing (got $rc)"
  FAIL=$((FAIL + 1))
fi

# Test 2: Registry file exists but is empty — should exit 2
mkdir -p "$tmpdir/.claude/plugins"
echo '' > "$tmpdir/.claude/plugins/installed_plugins.json"
rc=0; HOME="$tmpdir" bash "$SHIPWRIGHT/hooks/check-dockyard.sh" >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 2 ]; then
  echo "  PASS  check-dockyard.sh exits 2 when registry is empty"
  PASS=$((PASS + 1))
else
  echo "  FAIL  check-dockyard.sh should exit 2 when registry is empty (got $rc)"
  FAIL=$((FAIL + 1))
fi

# Test 3: Registry exists but no dockyard — should exit 2
echo '{"plugins":{}}' > "$tmpdir/.claude/plugins/installed_plugins.json"
rc=0; hook_output=$(HOME="$tmpdir" bash "$SHIPWRIGHT/hooks/check-dockyard.sh" 2>&1) || rc=$?
if [ "$rc" -eq 2 ]; then
  echo "  PASS  check-dockyard.sh exits 2 when dockyard missing from registry"
  PASS=$((PASS + 1))
else
  echo "  FAIL  check-dockyard.sh should exit 2 when dockyard missing (got $rc)"
  FAIL=$((FAIL + 1))
fi

# Test 4: Error message includes install command
if echo "$hook_output" | grep -q '/plugin install dockyard@shipwright-marketplace'; then
  echo "  PASS  check-dockyard.sh error includes install command"
  PASS=$((PASS + 1))
else
  echo "  FAIL  check-dockyard.sh error missing install command"
  FAIL=$((FAIL + 1))
fi

# Test 5: Registry has other plugins but not dockyard — should exit 2
echo '{"dockyard-tools@other-marketplace":{},"another@plugin":{}}' > "$tmpdir/.claude/plugins/installed_plugins.json"
rc=0; HOME="$tmpdir" bash "$SHIPWRIGHT/hooks/check-dockyard.sh" >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 2 ]; then
  echo "  PASS  check-dockyard.sh exits 2 when similar-named plugin present but not dockyard"
  PASS=$((PASS + 1))
else
  echo "  FAIL  check-dockyard.sh should exit 2 when similar-named plugin present (got $rc)"
  FAIL=$((FAIL + 1))
fi

# Test 6: Registry has dockyard — should exit 0
echo '{"plugins":{"dockyard@shipwright-marketplace":{}}}' > "$tmpdir/.claude/plugins/installed_plugins.json"
if HOME="$tmpdir" bash "$SHIPWRIGHT/hooks/check-dockyard.sh" >/dev/null 2>&1; then
  echo "  PASS  check-dockyard.sh exits zero when dockyard present"
  PASS=$((PASS + 1))
else
  echo "  FAIL  check-dockyard.sh should exit zero when dockyard present"
  FAIL=$((FAIL + 1))
fi

# --- Summary ---
echo ""
TOTAL=$((PASS + FAIL))
echo "validate-structure: $PASS/$TOTAL passed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
