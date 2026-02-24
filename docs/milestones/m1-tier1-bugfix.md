# Milestone 1 — Tier 1 Bug Fix Workflow

**Date:** 2026-02-24
**Status:** Design complete. Ready for implementation.
**Goal:** A working Tier 1 bug fix workflow, installable via plugin marketplace.

---

## What M1 Delivers

A developer installs Shipwright, runs `/shipwright`, describes a bug (or passes a Jira ticket), and gets a disciplined fix: root-cause investigation, TDD, verification, code review — with codebase context and crash recovery. Three standalone commands are also available outside the orchestrated workflow.

---

## Skills (6)

All skills are adapted from existing open-source projects with attribution.

| Skill | Source | Source file | Adaptation |
|-------|--------|------------|------------|
| TDD | [Superpowers](https://github.com/obra/superpowers) by Jesse Vincent | `skills/test-driven-development/SKILL.md` | Rename, add attribution header |
| Verification-before-completion | [Superpowers](https://github.com/obra/superpowers) by Jesse Vincent | `skills/verification-before-completion/SKILL.md` | Rename, add attribution |
| Systematic debugging | [Superpowers](https://github.com/obra/superpowers) by Jesse Vincent | `skills/systematic-debugging/SKILL.md` | Rename, add attribution |
| Anti-rationalization (standalone) | [Superpowers](https://github.com/obra/superpowers) by Jesse Vincent | Extracted from TDD + debugging skills | New lightweight file for Reviewer/Validator; anti-rationalization remains embedded in TDD and debugging for Implementer |
| Decision categorization | [GSD](https://github.com/gsd-build/get-shit-done) by gsd-build | `commands/gsd/discuss-phase.md` | Adapt CONTEXT.md output to Shipwright's decision log (LOCKED/DEFERRED/DISCRETION) |
| Brownfield analysis | [GSD](https://github.com/gsd-build/get-shit-done) by gsd-build | `agents/gsd-codebase-mapper.md` + `commands/gsd/map-codebase.md` | Adapt to 7-doc structure in `docs/codebase-profile/`, add staleness check logic. See `docs/skills/brownfield/mvp-requirements.md` |

### Anti-rationalization approach

Anti-rationalization is handled two ways:
- **Embedded** in TDD and systematic debugging skills (as Superpowers does) — these include "Red Flags" tables and rationalization counters. The Implementer gets this automatically.
- **Standalone** lightweight version for Reviewer and Validator, who don't get TDD or debugging skills but still need to resist shortcuts like "looks fine" without verification.

### Brownfield analysis artifacts

Adapted from GSD's 7-doc structure. Produced in `docs/codebase-profile/`:

| File | Content |
|------|---------|
| `STACK.md` | Languages, frameworks, dependencies, build tools |
| `INTEGRATIONS.md` | External APIs, databases, services, auth providers |
| `ARCHITECTURE.md` | Module structure, key abstractions, data flow |
| `STRUCTURE.md` | Directory layout, file locations, where to add new code |
| `CONVENTIONS.md` | Naming, patterns, file organization, code style |
| `TESTING.md` | Test framework, commands, file organization, mocking |
| `CONCERNS.md` | Known debt, fragile areas, security-sensitive zones |
| `.last-analyzed` | JSON tracking last full and fast-path commit SHAs |

Staleness check runs on every `/shipwright` invocation. See `docs/skills/brownfield/mvp-requirements.md` for full requirements.

---

## Agents (5)

Each agent is a markdown prompt template loaded into a fresh, ephemeral subagent. The orchestrator spawns it, injects the prompt, the subagent does its work and dies.

| Agent | Prompt file | Skills injected | Responsibilities |
|-------|------------|-----------------|------------------|
| **Triage** | `agents/triage.md` | Brownfield analysis, Decision categorization | Read codebase profiles (run analysis if stale), do deeper code-level analysis as needed, brainstorm with user, categorize decisions, confirm Tier 1 |
| **Implementer** | `agents/implementer.md` | TDD, Verification, Systematic debugging (anti-rationalization embedded) | Investigate root cause, write failing test, fix, verify |
| **Reviewer** | `agents/reviewer.md` | Anti-rationalization (standalone) | Review for spec compliance then code quality, approve/challenge (once)/escalate to human |
| **Validator** | `agents/validator.md` | Verification, Anti-rationalization (standalone) | Run full regression, confirm fix |
| **Doc Digest** | `agents/doc-digest.md` | — | Walk user through documents section by section |

### Validator test discovery

The Validator needs to know how to run tests. It uses a cascading lookup:

1. **State file** — if Triage recorded the test command during analysis
2. **Brownfield `TESTING.md`** — documents test framework and commands
3. **CLAUDE.md** — many repos already specify test commands here
4. **Ask the user** — fallback if none of the above resolve it

---

## Orchestrator

Single file: `commands/shipwright.md`. Pure dispatcher — never does work itself.

### Entry point parsing

`/shipwright` accepts optional inline context:

| Input | Example | Behavior |
|-------|---------|----------|
| No args | `/shipwright` | Triage asks the user what they're working on |
| Natural language | `/shipwright fix null pointer when user clicks more details` | Pass description to Triage as initial context |
| Jira ticket | `/shipwright fix bug RAI-9874` | Detect `[A-Z]+-\d+` pattern. Check if Atlassian MCP is available. If yes, fetch ticket details (title, description, acceptance criteria) and pass to Triage. If no, warn user that Atlassian MCP is not configured and ask them to paste the ticket details manually. |

### Flow

```
/shipwright [optional context]
  → Parse input (no args / natural language / Jira ticket)
  → If Jira ticket: check Atlassian MCP availability → fetch or warn
  → Read recovery files (state.json + CONTEXT.md) — resume if exists
  → Spawn Triage (brownfield staleness check → brainstorm → confirm Tier 1)
  → Spawn Implementer (root cause → failing test → fix → verify)
  → Spawn Reviewer (spec compliance → code quality → approve/challenge/escalate)
  → Spawn Validator (full regression → confirm fix)
  → Done
```

### Orchestrator responsibilities

- Never does work itself — only routes
- Reads recovery files before every subagent spawn
- Writes `state.json` + `CONTEXT.md` after every step
- Detects Jira ticket patterns and checks for Atlassian MCP before attempting fetch

---

## Recovery (Layer 1 + 4)

Two files in `.workflow/` (gitignored):

### Layer 1 — State file

`.workflow/state.json` (~500 tokens, updated every step):

```json
{
  "session_id": "uuid",
  "tier": 1,
  "phase": "implement",
  "step": "tdd-fix",
  "status": "in_progress",
  "active_agent": "implementer",
  "feature_branch": "fix/RAI-9874",
  "test_command": "npm test",
  "input_context": "RAI-9874: null pointer on more details click",
  "artifacts": ["docs/codebase-profile/"]
}
```

### Layer 4 — Rolling context

`.workflow/CONTEXT.md` (capped at 200 lines, rewritten not appended):

- What we're fixing and why
- Current phase and what just happened
- What's next
- Key decisions made so far
- Open blockers

### Recovery behavior

- Orchestrator reads both files before every subagent spawn
- If session exists and status is `in_progress`, resume from last step
- If no session exists, start fresh

---

## Standalone Commands

Three commands usable outside the orchestrated workflow. Stateless — no `.workflow/`, no recovery, no orchestrator.

| Command | Agent | Skill | What it does |
|---------|-------|-------|-------------|
| `/shipwright:codebase-analyze` | Triage | Brownfield analysis | Full codebase analysis regardless of staleness. Writes 7 profile docs to `docs/codebase-profile/`. |
| `/shipwright:doc-digest` | Doc Digest | — | Walk through any document section by section for interactive review. |
| `/shipwright:debug` | Implementer | Systematic debugging | Standalone 4-phase debugging: root cause → pattern analysis → hypothesis testing → fix. No Triage/Reviewer/Validator. |
| `/shipwright:report` | — | — | File bugs, enhancements, suggestions, and feedback as GitHub issues on `RelationalAI/shipwright`. |

### `/shipwright:report` behavior

| Input | Example | Behavior |
|-------|---------|----------|
| No args | `/shipwright:report` | Ask user to pick type (bug, feature, suggestion, feedback), then collect title and description |
| Free-form | `/shipwright:report clicking more details throws a null pointer` | Decipher the type from the text (this is a bug), confirm with the user, then collect any missing details |

Creates a GitHub issue on `RelationalAI/shipwright` using `gh issue create` with the appropriate label (bug, feature, suggestion, feedback).

---

## Plugin Structure

```
plugins/shipwright/
  .claude-plugin/plugin.json
  skills/
    tdd.md
    verification-before-completion.md
    systematic-debugging.md
    anti-rationalization.md
    decision-categorization.md
    brownfield-analysis.md
  agents/
    triage.md
    implementer.md
    reviewer.md
    validator.md
    doc-digest.md
  commands/
    shipwright.md                    # main orchestrated workflow
    shipwright-codebase-analyze.md   # standalone brownfield analysis
    shipwright-doc-digest.md         # standalone doc walkthrough
    shipwright-debug.md              # standalone systematic debugging
    shipwright-report.md             # file issues on Shipwright repo
```

**Install (local):**
```bash
git clone git@github.com:RelationalAI/shipwright.git
cd shipwright
/install-plugin .
# restart session
/shipwright
```

> Marketplace install via `RelationalAI/claude-plugins` registry is planned but not yet available.

---

## Not in M1

| What | Why deferred |
|------|-------------|
| Tiers 2 and 3 | M1 is Tier 1 only |
| Planner, Doc Writer, Security Assessor, Cost Analyzer, Researcher, Requirements agents | Tier 2/3 agents |
| Recovery Layers 2 and 3 (decision log compaction, checkpoints) | Tier 1 sessions are short — basic recovery is sufficient |
| Wave-based parallel execution | No planning phase in Tier 1 |
| Goal-backward verification | Deferred to M2 |
| Cost reporting | Tier 1 sessions are short and cheap — add when Tier 2 brings longer sessions |
| Standalone security-review, security-threat-model, code-review, pr-review | Tier 2/3 assessment commands |

---

## Success Criteria

- A developer can install Shipwright from the plugin marketplace
- `/shipwright` starts a Tier 1 workflow for a bug fix
- `/shipwright fix bug RAI-XXXX` fetches Jira ticket details (if Atlassian MCP available)
- Triage reads codebase profiles (runs analysis if stale) and confirms tier
- Implementer uses TDD and systematic debugging to fix the bug
- Reviewer reviews the fix
- Validator discovers the test command and runs full regression
- If context is lost mid-session, the orchestrator recovers from state.json + CONTEXT.md
- `/shipwright:codebase-analyze`, `/shipwright:doc-digest`, `/shipwright:debug`, and `/shipwright:report` work standalone
- `/shipwright:report` creates a GitHub issue on `RelationalAI/shipwright` with the correct label
