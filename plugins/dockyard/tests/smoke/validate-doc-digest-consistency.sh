#!/usr/bin/env bash
#
# validate-doc-digest-consistency.sh — Verify internal consistency between
# the doc-digest skill and command files.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
SKILL="$REPO_ROOT/plugins/dockyard/skills/doc-digest/SKILL.md"
COMMAND="$REPO_ROOT/plugins/dockyard/commands/doc-digest.md"
PASS=0
FAIL=0

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

echo "=== validate-doc-digest-consistency ==="

# --- Both files exist ---
echo ""
echo "File presence:"
for f in "$SKILL" "$COMMAND"; do
  label=$(basename "$(dirname "$f")")/$(basename "$f")
  if [ -s "$f" ]; then
    pass "$label exists"
  else
    fail "$label missing or empty"
  fi
done

# Agent file should NOT exist (deleted in redesign)
AGENT="$REPO_ROOT/plugins/dockyard/agents/doc-digest.md"
if [ -f "$AGENT" ]; then
  fail "agent file should not exist (agents/doc-digest.md still present)"
else
  pass "agent file correctly removed"
fi

# --- Skill has required sections ---
echo ""
echo "Skill structure:"
if grep -q '^## Review Loop' "$SKILL"; then
  pass "skill has Review Loop section"
else
  fail "skill missing Review Loop section"
fi

if grep -q '^## Wrap-up' "$SKILL"; then
  pass "skill has Wrap-up section"
else
  fail "skill missing Wrap-up section"
fi

# --- Review Loop contains key elements ---
echo ""
echo "Review Loop content:"
review_section=$(awk '/^## Review Loop/{found=1; next} found && /^## /{exit} found' "$SKILL")

if echo "$review_section" | grep -q 'Section N of M'; then
  pass "review loop references section numbering"
else
  fail "review loop missing section numbering pattern"
fi

if echo "$review_section" | grep -qi 'summary'; then
  pass "review loop includes summary analysis"
else
  fail "review loop missing summary analysis"
fi

if echo "$review_section" | grep -qi 'problems'; then
  pass "review loop includes problems analysis"
else
  fail "review loop missing problems analysis"
fi

if echo "$review_section" | grep -qi 'wait.*user\|wait.*response'; then
  pass "review loop requires waiting for user"
else
  fail "review loop missing wait-for-user instruction"
fi

# --- Code file exclusion ---
echo ""
echo "Guardrails:"
if grep -q 'code-review' "$SKILL"; then
  pass "skill redirects code files to code-review"
else
  fail "skill missing code-review redirect"
fi

# --- Skill defines the 2000-line guardrail ---
if grep -q '2000' "$SKILL"; then
  pass "skill defines 2000-line guardrail"
else
  fail "skill missing 2000-line guardrail"
fi

# --- Command references the skill ---
echo ""
echo "Command-skill linkage:"
if grep -q 'skills/doc-digest/SKILL.md' "$COMMAND"; then
  pass "command references skill by path"
else
  fail "command does not reference skills/doc-digest/SKILL.md"
fi

echo ""
TOTAL=$((PASS + FAIL))
echo "validate-doc-digest-consistency: $PASS/$TOTAL passed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
