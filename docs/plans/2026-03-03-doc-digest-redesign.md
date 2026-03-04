> **SUPERSEDED** — See [2026-03-04-doc-digest-v3-design.md](2026-03-04-doc-digest-v3-design.md)

# Doc Digest Redesign — Design

Supersedes `2026-03-01-doc-digest-design.md`. Incorporates PR #36 review feedback.

## Goal

A reading companion that chunks documents, presents them section by section, and offers compact analysis. Users give feedback or request changes inline; the tool tracks everything and offers to apply remaining changes at the end.

## What Changed From v1

| Removed | Reason |
|---------|--------|
| Agent file | Interactive workflow is a poor fit for subagents. Command + skill is sufficient. |
| Disposition system (edit/suggestion modes) | Replaced by intent inference from natural language. |
| PR detection and comment posting | Out of scope for a reading companion. |
| Code file chunking | That's code review, not doc-digest. |

| Added | Reason |
|-------|--------|
| Inline change application | Users can request edits at any point, not just end of review. |
| Intent inference | Replaces disposition modes — imperative instructions trigger edits, observations are logged as feedback. |

## File Structure

| File | Role |
|------|------|
| `commands/doc-digest.md` | Entry point. Takes `$ARGUMENTS` as doc path, invokes skill directly. |
| `skills/doc-digest/SKILL.md` | Complete methodology: chunking, presentation, analysis, feedback, change tracking, output. |

No agent file.

## Section Chunking

**Supported file types:** Markdown, YAML/JSON, plain text. No code files.

Layered strategy — headings first, semantic fallback:

1. **Markdown with headings:** Split on `##` (fall back to `#` if no `##` found)
2. **Oversized sections (>150 lines):** Sub-chunk at `###` headings, code fence boundaries, or blank-line blocks. Sub-chunks tracked as 3a, 3b, 3c.
3. **Tiny adjacent sections (<5 lines):** Merge for presentation, track individually.
4. **Non-markdown:** YAML/JSON → top-level keys. Plain text → blank-line paragraphs.

**Size target:** 30–150 lines per chunk. Never break mid-paragraph or mid-code-block.

**Presentation:** `Section 3 of 12: Retry Policy (lines 84–142)`

**Rendering:** Markdown rendered directly. YAML/JSON in fenced blocks with language tag.

**Guardrail:** If document exceeds 2000 lines, warn user and suggest batches. Proceed if they insist.

## Per-Section Analysis

After presenting each section, show a compact analysis block.

**Flags** (only if issues found):
- **Inconsistency** — contradicts another section (cite which)
- **Clarity** — ambiguous language, undefined terms
- **Completeness** — missing content that other sections reference
- **Redundancy** — repeats content covered elsewhere

No issues = no flags. No filler. Analysis uses full document context (loaded once at setup). Each flag cites the specific section or content it references. Target: 50–100 tokens per analysis block.

**Prompt:** "Any feedback, or ready to move on?"

## Feedback Handling

**Section statuses:** `pending` → `approved` | `has-feedback` | `punted`

| User says | Status | Action |
|-----------|--------|--------|
| "looks good", "next", "lgtm" | `approved` | Move to next section |
| "skip", "punt" | `punted` | Log optional reason, move on |
| Opinion/observation ("this is unclear", "timeout seems low") | `has-feedback` | Log as feedback, continue |
| Actionable instruction ("fix this", "change timeout to 30s") | `has-feedback` | Apply edit, run ripple check, log in change tracker |

**Intent inference:** Imperative verb + specific change → apply immediately. Opinion or observation → log as feedback. Ambiguous → ask: "Want me to apply that change, or just note it as feedback?"

**Navigation:** Users can jump to any section by number, check review status, or ask clarifying questions at any point.

## Cross-Section Ripple Propagation

Triggered only when user requests a change:

1. Make the requested edit
2. Scan full document for references to the changed content
3. If ripples found: tell the user what's affected, ask whether to fix
4. If approved: apply ripple edits, log each as type `ripple`
5. If declined: log potential ripple as a note
6. **Never make silent changes**

When a ripple-affected section comes up later: "Already updated due to change in section N."

## Output & End of Review

**1. Stats:** `Reviewed 12 sections: 8 approved, 3 with feedback, 1 punted`

**2. Change log table** (if changes or feedback logged):

| # | Section | Type | Description | Status |
|---|---------|------|-------------|--------|
| 1 | 3. Retry Policy | edit | Changed timeout from 10s to 30s | applied |
| 2 | 7. Rollback | ripple | Updated threshold to match section 3 | applied |
| 3 | 5. Permissions | feedback | "Role definitions seem incomplete" | noted |
| 4 | 11. FAQ | punted | Revisit after retry finalized | — |

Types: `edit`, `ripple`, `punted`, `feedback`. Status: `applied` or `noted`.

**3. Follow-up:** "Want me to apply any of the noted feedback, revisit any section, or is the review complete?"

## Token Efficiency

- Skill: terse rules, no verbose examples
- Command: ~10 lines
- Document loaded once at setup, not re-read per section
- Analysis blocks compact (~50–100 tokens)
- Change tracker: structured data, not prose
- Correctness takes precedence over token savings

## Testing

### Layer 1 — Structural (no API, CI-safe)

Smoke test validates:
- Command and skill files exist and are non-empty
- Skill references all statuses: `pending`, `approved`, `has-feedback`, `punted`
- Skill references change log types: `edit`, `ripple`, `punted`, `feedback`
- Skill references analysis flags: `Inconsistency`, `Clarity`, `Completeness`, `Redundancy`
- Command references skill (not agent)
- Skill mentions 2000-line guardrail and 150-line threshold

No agent linkage checks. No disposition type checks. No PR integration checks.

### Layer 2 — Behavioral (API-based, manual)

Test harness in `tests/behavioral/doc-digest/`. 5 tests:

1. **Section presentation** — markdown fixture, present first section, verify header + analysis + prompt
2. **Inconsistency detection** — contradictory fixture, verify flags raised
3. **Summary format** — verify stats line + table formatting
4. **Non-markdown chunking** — plain text fixture, verify section headers + analysis
5. **Sub-chunking** — large-section fixture, verify ≥2 chunks with sub-notation

Test fixtures: `test-markdown.md`, `test-large-section.md`, `test-no-headings.txt`, `test-inconsistent.md`

~4–5 API calls per run. Manual or release-gated, not CI.
