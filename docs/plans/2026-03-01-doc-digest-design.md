> **SUPERSEDED** — See [2026-03-04-doc-digest-v3-design.md](2026-03-04-doc-digest-v3-design.md)

# Doc Digest Improvements — Design

## Goal

Upgrade the doc-digest system from a simple section-by-section walkthrough into a context-aware interactive review tool with analysis, change tracking, and PR integration.

## File Structure

| File | Role |
|------|------|
| `commands/doc-digest.md` | Thin dispatcher. Passes `$ARGUMENTS`, reads skill, spawns agent. |
| `skills/doc-digest/SKILL.md` | Full interactive review methodology — chunking, analysis, feedback, change tracking, output format. |
| `agents/doc-digest.md` | Agent identity + orchestration — disposition detection, PR integration, cross-section change propagation. References `skills/doc-digest/SKILL.md`. |

## Section Chunking

Layered strategy — headings first, semantic fallback:

1. **Markdown with headings:** Split on `##` (fall back to `#`)
2. **Oversized sections (>150 lines):** Sub-chunk at sub-headings, code fence boundaries, or blank-line-separated blocks. Sub-chunks tracked as 3a, 3b, 3c under parent.
3. **Non-markdown:** Code → function/class boundaries. YAML/JSON → top-level keys. Plain text → blank-line paragraphs.
4. **Tiny adjacent sections (<5 lines):** Merge for presentation, track individually.

**Size target:** 30–150 lines per chunk. Never break mid-paragraph or mid-code-block.

**Presentation:** Show line range for orientation: `Section 3 of 12: Retry Policy (lines 84–142)`

**Rendering:** Markdown content rendered directly (not in code fences). Code/YAML/JSON in fenced blocks with language tag.

## Per-Section Analysis

After presenting each section, show a compact analysis block:

**Summary** — 1-2 sentences: what the section says, its role in the document.

**Flags** (only if issues found):
- **Inconsistency** — contradicts another section (cite which)
- **Clarity** — ambiguous language, undefined terms
- **Completeness** — missing content that other sections reference
- **Redundancy** — repeats content covered elsewhere

No issues = no flags section. No filler.

Analysis is performed against the full document context — the agent reads the entire document at setup and holds it throughout.

## Feedback & Disposition

**Session-level disposition**, not per-feedback:

1. Agent checks for open PR touching the file (`gh pr list`)
2. PR found → default **suggestion** mode. No PR → default **edit** mode.
3. If uncertain, ask the user once. Lock for session.
4. User can flip disposition mid-session ("switch to suggestions" / "start editing").

**If user says "fix this" in suggestion mode:** Agent asks "I'm in suggestion mode — want me to switch to editing, or record as suggestion?"

| User says | Disposition | Action |
|-----------|-------------|--------|
| "This should say X" | Session default | Edit or record suggestion |
| "Fix this" / "Change it" | Edit (or ask if in suggestion mode) | Make the change |
| "Note this" / "Suggest" | Suggestion | Record it |
| "Skip" / "Punt" | Punted | Record with optional reason |

## Cross-Section Awareness

**Analysis:** Each section analyzed in context of the full document. The agent knows what prior sections established and what later sections expect.

**Change propagation (edit mode):**
1. User requests change in section N
2. Agent scans full document for references to same concept/value
3. If found: "This affects sections X and Y — updating both." (Tell, then do.)
4. All changes logged as `ripple` entries
5. When affected sections come up later: "Already updated due to change in section N"

**Document size guardrail:** If document exceeds 2000 lines:
- Warn the user about potential quality degradation
- Suggest reviewing in logical batches
- If user insists on full review, proceed with caveat noted

## Change Tracking & Final Summary

Running change log throughout the review. Final output:

**1. Stats:** `Reviewed 12 sections: 8 approved, 3 with feedback, 1 punted`

**2. Change log table:**

| # | Section | Type | Description | Status |
|---|---------|------|-------------|--------|
| 1 | 3. Retry Policy | Edit | Changed max retries 5→3 | Applied |
| 2 | 7. Monitoring | Ripple | Updated retry ref 5→3 | Applied |
| 3 | 5. Error Handling | Suggestion | Add fallback after max retries | Pending |
| 4 | 11. FAQ | Punted | Revisit after retry finalized | — |

**3. PR comment posting (suggestion mode + PR detected):**
- Show proposed comments table
- User edits/removes/approves
- Post via `gh` on approval

**4. Wrap-up:** "Want to revisit any section, or is the review complete?"

## Token Efficiency

- Skill: terse rules and formats, no verbose examples
- Agent: orchestration only, references skill instead of duplicating
- Command: ~10 lines
- Document loaded once at setup, not re-read per section
- Analysis blocks compact (~50-100 tokens each)
- Change tracker is structured data, not prose

Correctness takes precedence over token savings.

## Testing

### Layer 1 — Structural (no API, CI-safe)

Extend existing smoke tests:
- `validate-skills.sh`: add `doc-digest`, verify frontmatter, no banned references
- `validate-agents.sh`: verify `dockyard:doc-digest` skill reference, `## Output` section
- **New prompt consistency script:**
  - All status values defined are used in output format
  - All disposition types appear in tracking and summary
  - Analysis flag categories match output expectations

### Layer 2 — Behavioral (API-based, manual)

Test harness in `tests/behavioral/doc-digest/`:
- Sample doc + scripted user responses → Claude API → assert output structure
- Assertions: analysis blocks present, summary table present, section count matches

**Test fixtures:**
- `test-markdown.md` — well-structured headings
- `test-large-section.md` — one section >150 lines (sub-chunking)
- `test-no-headings.txt` — plain text (semantic chunking)
- `test-inconsistent.md` — deliberate contradictions (cross-section analysis)

~4-5 API calls per run. Manual or release-gated, not CI.
