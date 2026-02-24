# Brownfield Analysis Skill — MVP Requirements

**Date:** 2026-02-24
**Status:** Draft
**Source:** GSD idea #14, adapted for Shipwright

---

## What It Does

Analyzes an existing codebase and produces a set of focused profile documents covering tech stack, architecture, conventions, and concerns. These profiles give every Shipwright agent baseline context about the repo they're working in.

## Artifacts

```
docs/codebase-profile/
├── tech-stack.md       # Languages, frameworks, dependencies, build tools
├── architecture.md     # Module structure, key abstractions, data flow
├── conventions.md      # Naming, patterns, file organization, test conventions
├── concerns.md         # Known debt, fragile areas, security-sensitive zones
└── .last-analyzed      # Commit SHA of last full analysis
```

Each file targets one aspect of the codebase. CLAUDE.md references the directory so agents are aware of it.

## Staleness Check and Analysis Modes

### 1. Staleness check (always runs)
- Compare HEAD against the most recent SHA in `.last-analyzed` (full or fast-path, whichever is newer)
- If they match, skip — profiles are current
- If new commits exist, decide: fast-path or full analysis

### 2. Fast-path (incremental)
- Diffs changed files since the last analysis (full or fast-path)
- Updates only the affected profile sections based on the delta
- Cheap — reads changed files, not the whole repo
- After many fast-paths without a full run, profiles can drift. If 10+ commits have accumulated since the last full analysis, auto-trigger a full analysis instead. (10 is an arbitrary starting point — tweak based on experience.)

### 3. Full analysis
- Analyzes the whole repo from scratch across all 4 aspects
- Rewrites all profile files completely
- Triggered by: fast-path threshold exceeded (10+ commits since last full), or manual re-run

### 4. Manual re-run
- `/shipwright:codebase-analyze` runs a full analysis regardless of staleness
- Uses the existing standalone assessment command from the design doc

### Tracking file

`.last-analyzed` is JSON, not a plain SHA:

```json
{
  "last_full_sha": "abc123",
  "last_full_date": "2026-02-24",
  "last_fastpath_sha": "def456",
  "last_fastpath_date": "2026-02-24"
}
```

Staleness check compares HEAD against whichever SHA is more recent. Fast-path diffs against whichever it last ran from. Full analysis resets both.

## Integration with Tier 1

- Triage reads all profiles at the start of every Tier 1 workflow
- Profiles are small (targeted, one aspect each) so token cost is low
- Full context is cheap insurance for "simple" bugs that touch sensitive areas

## Injected Into

- **Triage agent** — runs the staleness check and triggers analysis when needed. Brownfield profiles are a starting point, not the end of Triage's investigation. Based on the specific task, Triage may do deeper code-level analysis (reading specific files, tracing call paths, understanding module boundaries) before routing.
- All other agents get passive access via CLAUDE.md reference

## Committed to Repo

All profile files under `docs/codebase-profile/` are committed to git. They are human-readable and useful for onboarding, not just agents.
