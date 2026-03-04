# Code Review Output Schema

The review produces structured JSON output that the invoking system parses. Using a consistent schema enables automated threshold enforcement, CI integration, and testing.

## Schema

```json
{
  "recommendation": "APPROVE | NEEDS_CHANGES",
  "findings": [
    {
      "file": "exact/file/path.ts",
      "line_start": 42,
      "line_end": 45,
      "severity": "blocker | warning | nit",
      "category": "correctness | convention | test-quality",
      "confidence": 80,
      "description": "What the issue is and why it matters",
      "suggested_fix": "Concrete suggestion for how to resolve it",
      "citation": "Exact quoted text from CLAUDE.md (convention findings only, null otherwise)"
    }
  ],
  "summary": "Overall assessment: what the diff does well, key concerns, where the human reviewer should focus"
}
```

## Field Rules

- **recommendation**: `NEEDS_CHANGES` if any finding has `severity: "blocker"`. Otherwise `APPROVE`.
- **findings**: Only findings surviving the confidence threshold (see `scoring-rubric.md`). Empty array if none survive.
- **severity**:
  - `blocker` — must fix before merge (correctness defect, security issue, critical convention violation)
  - `warning` — should fix, important but not blocking
  - `nit` — suggestion, style, minor improvement, optional
- **category**: Which review pass produced the finding.
- **confidence**: Integer from the scoring rubric, at or above the threshold defined in `scoring-rubric.md`.
- **citation**: Required for `convention` category — must be exact quoted text from `CLAUDE.md`. Set to `null` for other categories.
- **summary**: 2-4 sentences. Be specific about what the diff does well and where the human reviewer should focus.
