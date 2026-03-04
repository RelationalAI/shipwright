#!/usr/bin/env bash
#
# run-tests.sh — Behavioral tests for the doc-digest skill (v3).
#
# Requires: ANTHROPIC_API_KEY environment variable
# These tests call the Claude API and cost tokens. Run manually, not in CI.
#
set -euo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../../../../.." && pwd)"
SKILL="$REPO_ROOT/plugins/dockyard/skills/doc-digest/SKILL.md"
FIXTURES="$TEST_DIR/fixtures"
PASS=0
FAIL=0
SKIP=0

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  SKIP  $1"; SKIP=$((SKIP + 1)); }

# --- Preflight ---
if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "ANTHROPIC_API_KEY not set. Skipping behavioral tests."
  exit 0
fi

if ! command -v curl &>/dev/null || ! command -v jq &>/dev/null; then
  echo "curl and jq are required. Skipping behavioral tests."
  exit 0
fi

MODEL="${DOC_DIGEST_TEST_MODEL:-claude-haiku-4-5-20251001}"

LAST_STOP_REASON=""

call_claude() {
  local system_prompt="$1"
  local user_message="$2"

  local response
  response=$(curl -s https://api.anthropic.com/v1/messages \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
    -d "$(jq -n \
      --arg model "$MODEL" \
      --arg system "$system_prompt" \
      --arg user "$user_message" \
      '{
        model: $model,
        max_tokens: 4096,
        temperature: 0,
        system: $system,
        messages: [{role: "user", content: $user}]
      }')")

  if ! echo "$response" | jq -e . &>/dev/null; then
    echo "API_ERROR: Non-JSON response" >&2
    LAST_STOP_REASON="error"
    echo "API_ERROR"
    return
  fi

  if echo "$response" | jq -e '.error' &>/dev/null; then
    echo "API_ERROR: $(echo "$response" | jq -r '.error.message')" >&2
    LAST_STOP_REASON="error"
    echo "API_ERROR"
    return
  fi

  LAST_STOP_REASON=$(echo "$response" | jq -r '.stop_reason // "unknown"')
  echo "$response" | jq -r '.content[0].text // "ERROR: no content"'
}

echo "=== doc-digest behavioral tests (v3) ==="
echo "Model: $MODEL"
echo ""

SKILL_CONTENT=$(cat "$SKILL")
SYSTEM="$(printf 'You are the Doc Digest assistant.\n\nSKILL:\n%s' "$SKILL_CONTENT")"

# --- Test 1: Section presentation ---
echo "Test 1: Section presentation"
DOC_CONTENT=$(cat "$FIXTURES/test-markdown.md")

USER="$(printf 'Review this document. Present only the FIRST section, then stop and wait.\n\nDocument path: test-markdown.md\nDocument content:\n%s' "$DOC_CONTENT")"

RESULT_T1=$(call_claude "$SYSTEM" "$USER")

if [[ "$RESULT_T1" == "API_ERROR" || -z "$RESULT_T1" ]]; then
  skip "Test 1 skipped — API call failed"
else
  if echo "$RESULT_T1" | grep -qiE 'section [0-9]+ of [0-9]+'; then
    pass "section header present (Section N of M)"
  else
    fail "section header missing"
  fi

  if echo "$RESULT_T1" | grep -qiE '(summary|overview|covers|describes)'; then
    pass "analysis contains summary"
  else
    fail "analysis missing summary"
  fi

  if echo "$RESULT_T1" | grep -qiE '(feedback|move on|next|thoughts|questions)\?'; then
    pass "feedback prompt present"
  else
    fail "feedback prompt missing"
  fi
fi

echo ""

# --- Test 2: Inconsistency detection ---
echo "Test 2: Inconsistency detection"
DOC_CONTENT=$(cat "$FIXTURES/test-inconsistent.md")

USER="$(printf 'Review this document. Present ALL sections with analysis. Do not wait for feedback — auto-approve each section.\n\nDocument path: test-inconsistent.md\nDocument content:\n%s' "$DOC_CONTENT")"

RESULT_T2=$(call_claude "$SYSTEM" "$USER")

if [[ "$RESULT_T2" == "API_ERROR" || -z "$RESULT_T2" ]]; then
  skip "Test 2 skipped — API call failed"
else
  FLAT_T2=$(echo "$RESULT_T2" | tr '\n' ' ')

  if echo "$FLAT_T2" | grep -qiE '(inconsisten|contradict|conflict|discrepanc|mismatch)'; then
    pass "inconsistency language detected"
  else
    fail "no inconsistency language found"
  fi

  if echo "$FLAT_T2" | grep -qiE '(inconsisten|contradict).{0,200}(approv|weekend|saturday|threshold|error.rate|5%|2%)'; then
    pass "specific contradiction identified"
  else
    fail "no specific contradiction identified"
  fi
fi

echo ""

# --- Test 3: Non-markdown chunking ---
echo "Test 3: Non-markdown chunking"
DOC_CONTENT=$(cat "$FIXTURES/test-no-headings.txt")

USER="$(printf 'Review this document. Present only the FIRST section, then stop and wait.\n\nDocument path: test-no-headings.txt\nDocument content:\n%s' "$DOC_CONTENT")"

RESULT_T3=$(call_claude "$SYSTEM" "$USER")

if [[ "$RESULT_T3" == "API_ERROR" || -z "$RESULT_T3" ]]; then
  skip "Test 3 skipped — API call failed"
else
  if echo "$RESULT_T3" | grep -qiE 'section [0-9]+ of [0-9]+'; then
    pass "plain text produces section headers"
  else
    fail "plain text missing section headers"
  fi

  if echo "$RESULT_T3" | grep -qiE '(summary|overview|covers|describes|about)'; then
    pass "plain text produces analysis"
  else
    fail "plain text missing analysis"
  fi
fi

echo ""

# --- Summary ---
echo "================================================================"
TOTAL=$((PASS + FAIL + SKIP))
echo "doc-digest behavioral tests: $PASS passed, $FAIL failed, $SKIP skipped (of $TOTAL)"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
