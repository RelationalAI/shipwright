#!/usr/bin/env bash
#
# run-all.sh — Run all smoke validation scripts and report summary.
#
# These are marketplace-wide validation tests that verify the structure
# of both the dockyard and shipwright plugins.
#
# -e intentionally omitted: we want to run all suites and report failures at the end
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0
FAILED_NAMES=()

run_suite() {
  local name="$1"
  local script="$2"
  TOTAL_SUITES=$((TOTAL_SUITES + 1))
  echo ""
  echo "================================================================"
  echo "Running: $name"
  echo "================================================================"
  if bash "$script"; then
    PASSED_SUITES=$((PASSED_SUITES + 1))
  else
    FAILED_SUITES=$((FAILED_SUITES + 1))
    FAILED_NAMES+=("$name")
  fi
}

run_suite "validate-structure" "$SCRIPT_DIR/validate-structure.sh"
run_suite "validate-skills"    "$SCRIPT_DIR/validate-skills.sh"
run_suite "validate-agents"    "$SCRIPT_DIR/validate-agents.sh"
run_suite "validate-commands"  "$SCRIPT_DIR/validate-commands.sh"

echo ""
echo "================================================================"
echo "SMOKE TEST SUMMARY"
echo "================================================================"
echo "Suites: $PASSED_SUITES/$TOTAL_SUITES passed"
if [ "$FAILED_SUITES" -gt 0 ]; then
  echo "Failed:"
  for name in "${FAILED_NAMES[@]}"; do
    echo "  - $name"
  done
  echo ""
  echo "RESULT: FAIL"
  exit 1
else
  echo ""
  echo "RESULT: PASS"
  exit 0
fi
