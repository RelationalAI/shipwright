# Orchestration Protocol

How to execute the three review passes with minimal context consumption.

Do NOT instruct sub-agents to write files. All communication is inline — sub-agents return their results as JSON in their response messages.

## Step 1: Run review passes

Spawn three Task sub-agents in parallel. Each sub-agent receives:
- The diff to review
- `CLAUDE.md` content
- Rationale context (if available)
- Its pass-specific reference file
- The output schema reference file
- Instruction to return findings as a JSON object in its response

```
Pass 1 (correctness):
  Read: references/pass-correctness.md
  Read: references/output-schema.md
  Return: { "pass": "correctness", "findings": [...] }

Pass 2 (conventions):
  Read: references/pass-conventions.md
  Read: references/output-schema.md
  Return: { "pass": "conventions", "findings": [...] }

Pass 3 (test quality):
  Read: references/pass-test-quality.md
  Read: references/output-schema.md
  Return: { "pass": "test-quality", "findings": [...] }
```

**Model:** Opus for all review passes (higher quality, fewer false positives).

Each sub-agent returns a JSON object containing its `pass` name and the `findings` array from the output schema. The coordinator extracts the findings from each sub-agent's response message.

## Step 2: Score findings

Spawn one Haiku Task sub-agent that receives:
1. All three findings arrays inline (passed from the coordinator's context)
2. The scoring rubric from `references/scoring-rubric.md`
3. The relevant diff context

The scorer:
1. Scores each finding independently
2. Drops findings below 75
3. Returns the final JSON output (recommendation + filtered findings + summary) in its response

## Step 3: Use results

Parse the scorer's response message to extract the final review result JSON. This is the only review data that enters the main context — the individual pass findings were consumed by the scorer sub-agent.
