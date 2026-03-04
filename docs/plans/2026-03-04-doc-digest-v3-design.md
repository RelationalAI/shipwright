# Doc-Digest v3 Design

**Date:** 2026-03-04
**Status:** Active
**Supersedes:** 2026-03-01-doc-digest-design.md, 2026-03-03-doc-digest-redesign.md

## Problem

The current doc-digest skill is overengineered (~112 lines) with formal sub-chunking notation, ripple propagation, intent inference rules, and a structured change tracker. Claude doesn't follow these prescriptive rules reliably. The fix is fewer rules, not different rules.

## Design

### Flow

Three phases:

1. **Setup** — Read the entire document into context. Split semantically into sections readable in ~30 seconds (~20-40 lines). Tell the user how many sections there are.
2. **Review loop** — For each section: show verbatim content with original formatting, then analysis (contextual summary + problems if any). Wait for user response. Handle questions, edit requests, or feedback naturally. Move on when the user is ready.
3. **Wrap-up** — Plain-language summary of issues found and feedback noted. Offer to apply noted feedback or revisit sections.

### Chunking

No mechanical rules. Claude reads the full document and splits at semantic boundaries: headings, topic shifts, natural breaks. Never break mid-paragraph or mid-code-block. For YAML/JSON, split on top-level keys or logical groupings.

### Per-Section Presentation

1. Header: `Section N of M: [Title]`
2. Content: verbatim with original formatting (markdown rendered as markdown, YAML/JSON in fenced blocks)
3. Analysis (after horizontal rule):
   - Summary: 1-2 sentences on what the section covers and how it relates to the rest of the document
   - Problems (only if found): described plainly, no formal category labels
4. Prompt: "Any questions or feedback, or ready to move on?"

### User Responses

- "next" / "looks good" — advance
- Question — answer using full doc context, ask to move on
- Edit request ("fix X") — apply the edit, confirm, move on
- Opinion ("this feels incomplete") — note as feedback, move on

### Wrap-up

Plain-language summary: sections reviewed, key issues, noted feedback. Offer to apply feedback or revisit. No formal table.

### Guardrails

- Documents over 2000 lines: warn and confirm before proceeding
- Code files excluded (use code-review instead)
- Supported types: markdown, YAML, JSON, plain text

## File Structure

- `skills/doc-digest/SKILL.md` — ~30-35 lines, rewritten from scratch
- `commands/doc-digest.md` — unchanged (invoke skill, use `$ARGUMENTS`)

## What Gets Deleted

- Old design docs marked as superseded (content preserved, status updated)
- Behavioral tests and fixtures (built for old design's specific behaviors)
- Smoke test assertions for internal terms (status names, flag categories, thresholds)

## What Gets Rewritten

- SKILL.md — from scratch
- Smoke test — simplified to structural checks
- Behavioral tests — new tests matching v3 behaviors
