# Confidence Scoring

After all review passes complete, each finding is scored independently by a separate scorer.

## Why Independent Scoring

Detection and evaluation are separate concerns. The review passes cast a wide net (high recall). The scorer filters noise (high precision). Combining both in one step leads to anchoring — the reviewer justifies its own findings rather than evaluating them objectively.

## Rubric

| Score | Meaning | Example |
|-------|---------|---------|
| 0 | False positive — does not hold up to scrutiny, or pre-existing issue | "Bug" that is actually handled by a try/catch 3 lines below |
| 25 | Might be real — could not verify with available context | Potential race condition, but unclear if this code path is concurrent |
| 50 | Verified real — but nitpick, rare in practice, or cosmetic | Unused import, inconsistent spacing that doesn't violate CLAUDE.md |
| 75 | Verified — very likely real, important, should be addressed | Missing null check on user input that will throw in production |
| 100 | Definitely real — evidence directly confirms, happens frequently | SQL injection via string concatenation with request parameter |

## Threshold

Drop all findings scoring below 80. Only findings scoring 80+ are included in the output.

## Scoring Process

For each finding, the scorer receives:
- The finding (file, line range, description, suggested fix)
- The relevant diff context
- The surrounding source code

The scorer evaluates each finding on its own merits. One finding's score must not influence another's.
