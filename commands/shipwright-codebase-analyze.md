---
description: Analyze codebase and produce 7 profile docs in docs/codebase-profile/
argument-hint: [optional: specific focus area]
---

# Codebase Analyze

You are running as a **standalone command**. There is no orchestrator, no recovery loop, and no `.workflow/` files. Execute the instructions below directly.

## Setup

Read the brownfield analysis skill from `skills/brownfield-analysis.md` in the Shipwright plugin directory. That skill defines the 7 output documents, their templates, the exploration strategy, and the forbidden-files list. Follow all of its rules.

## Execution

**Force a FULL analysis.** Ignore the staleness check and the fast-path logic entirely. Rewrite all 7 profile documents from scratch regardless of what `.last-analyzed` says or whether it exists.

### Focus area

If `$ARGUMENTS` is provided, treat it as a focus area hint (e.g., "testing", "architecture", "concerns"). Spend extra depth on that area -- read more files, produce richer examples and patterns. You must still produce all 7 documents; the hint only controls where you invest additional exploration time.

### Steps

1. **Create output directory** -- ensure `docs/codebase-profile/` exists.
2. **Explore the codebase** across the four focus areas defined in the skill (tech, arch, quality, concerns). Use Glob, Grep, Read, and Bash to read real files. Never guess.
3. **Respect the forbidden-files list** from the skill. Never read or quote secrets, keys, or credential files. Note their existence only.
4. **Write all 7 profile documents** using the templates from the skill:
   - `docs/codebase-profile/STACK.md`
   - `docs/codebase-profile/INTEGRATIONS.md`
   - `docs/codebase-profile/ARCHITECTURE.md`
   - `docs/codebase-profile/STRUCTURE.md`
   - `docs/codebase-profile/CONVENTIONS.md`
   - `docs/codebase-profile/TESTING.md`
   - `docs/codebase-profile/CONCERNS.md`
5. **Update the tracking file** at `docs/codebase-profile/.last-analyzed` with JSON containing the current HEAD SHA and today's date for both `last_full_sha`/`last_full_date` and `last_fastpath_sha`/`last_fastpath_date`.
6. **Report what you wrote** -- list all 7 files and their line counts.
7. **Offer to commit** the new or updated profile documents.
