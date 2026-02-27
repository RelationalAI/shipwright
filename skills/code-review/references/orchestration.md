# Orchestration Protocol

How to execute the three review passes with minimal context consumption.

## Context Conservation

Sub-agents write results to temp files instead of returning them in-context. This prevents raw findings from 4 agent invocations accumulating in the main context. Only the final filtered result enters context.

## Step 1: Create temp directory

```bash
REVIEW_DIR=$(mktemp -d)
```

## Step 2: Run review passes

Spawn three Task sub-agents in parallel. Each sub-agent receives:
- The diff to review
- `CLAUDE.md` content
- Rationale context (if available)
- Its pass-specific reference file
- The output schema reference file
- Instruction to write findings JSON to a specific file path

```
Pass 1 (correctness):
  Read: references/pass-correctness.md
  Read: references/output-schema.md
  Write findings to: $REVIEW_DIR/pass-1-findings.json

Pass 2 (conventions):
  Read: references/pass-conventions.md
  Read: references/output-schema.md
  Write findings to: $REVIEW_DIR/pass-2-findings.json

Pass 3 (test quality):
  Read: references/pass-test-quality.md
  Read: references/output-schema.md
  Write findings to: $REVIEW_DIR/pass-3-findings.json
```

**Model:** Opus for all review passes (higher quality, fewer false positives).

Each sub-agent writes a JSON file containing only the `findings` array from the output schema. The sub-agent's return message to the main context should be a one-line summary: "Found N potential issues in [category]. Findings written to [path]."

## Step 3: Score findings

Spawn one Haiku Task sub-agent that:
1. Reads all three findings files from `$REVIEW_DIR/`
2. Reads the scoring rubric from `references/scoring-rubric.md`
3. Reads the relevant diff context
4. Scores each finding independently
5. Drops findings below 75
6. Assembles the final JSON output (recommendation + filtered findings + summary)
7. Writes the result to `$REVIEW_DIR/review-result.json`

The scorer's return message: "Scored N findings, M survived (threshold 75). Result written to [path]."

## Step 4: Read results

Read `$REVIEW_DIR/review-result.json` into the main context. This is the only review data that enters the main context — the individual pass findings stay on disk.

## Step 5: Cleanup

```bash
rm -rf "$REVIEW_DIR"
```
