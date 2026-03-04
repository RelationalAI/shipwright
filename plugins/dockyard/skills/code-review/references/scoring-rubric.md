# Confidence Scoring

After all review passes complete, each finding is scored independently by a separate scorer.

## Why Independent Scoring

Detection and evaluation are separate concerns. The review passes cast a wide net (high recall). The scorer filters noise (high precision). Combining both in one step leads to anchoring — the reviewer justifies its own findings rather than evaluating them objectively.

## Scale

Scores are integers 0–100. 0 means false positive, 100 means certainty. Use the full range — the score reflects how confident you are that the finding is real and important.

## Threshold

Drop all findings scoring below 80. Only findings scoring 80+ are included in the output.

## Scoring Process

For each finding, the scorer receives:
- The finding (file, line range, description, suggested fix)
- The relevant diff context
- The surrounding source code

The scorer evaluates each finding on its own merits. One finding's score must not influence another's.
