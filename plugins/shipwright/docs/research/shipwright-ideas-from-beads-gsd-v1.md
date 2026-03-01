# Shipwright — Ideas from Beads and GSD

**Date:** 2026-02-23
**Status:** All 14 ideas reviewed. Decisions recorded below.

---

## From Beads

### 1. Semantic Memory Compaction
**What:** When context grows, AI summarizes old closed items into "digest" entries. 100 decisions → 1 summary. Preserves meaning, shrinks tokens 100x.
**Gap in Shipwright:** Our `decisions.md` grows unbounded. No compaction strategy — will bloat over long Tier 3 sessions.
**Priority:** HIGH — directly impacts amnesia recovery cost.

### 2. Dependency-Aware Task Graph
**What:** Tasks have typed dependencies: `blocks`, `waits-for`, `conditional-blocks` (run if A fails). `bd ready` automatically returns only unblocked tasks.
**Gap in Shipwright:** Planner creates task lists, but dependency resolution is implicit. No error-handling dependencies.
**Priority:** MEDIUM — wave-based execution (from GSD) may cover most of this.

### 3. Hash-Based Collision-Free IDs
**What:** Tasks get hash IDs from UUIDs, not sequential numbers. Multiple agents can create tasks concurrently with zero collisions.
**Gap in Shipwright:** Not a problem yet (single orchestrator), but matters if we run parallel Implementer subagents that create subtasks.
**Priority:** LOW — future-proofing, not urgent.

### 4. Deferred Tasks with Time-Based Scheduling
**What:** `--defer-until "2025-03-01"` hides tasks from the ready queue until a date.
**Gap in Shipwright:** No concept of "not now, but later." All tasks are either pending or blocked.
**Priority:** LOW — nice to have for long-running projects.

### 5. Inter-Agent Messaging
**What:** First-class mail system between agents. Agents can notify each other within the issue graph.
**Gap in Shipwright:** Agents only communicate via the orchestrator. No direct agent-to-agent signaling.
**Priority:** LOW — orchestrator routing is sufficient for now.

### 6. Lean Context Injection via CLI Hooks
**What:** `bd prime` injects ~1-2K tokens of context vs 10-50K for full MCP schemas. Lean context = faster inference.
**Gap in Shipwright:** Orchestrator reads recovery files but we haven't optimized for minimal context injection.
**Priority:** MEDIUM — aligns with our "cheap by default" recovery philosophy.

---

## From GSD

### 7. Goal-Backward Verification
**What:** Verifier checks "did you achieve the goal?" not "did you complete the tasks?" Three independent verification layers. Task complete ≠ goal achieved.
**Gap in Shipwright:** Validator runs tests and checks pass/fail but doesn't verify against the original goal.
**Priority:** HIGH — catches "all tests pass but the feature doesn't work" failure mode.

### 8. User Decision Categorization (discuss-phase)
**What:** Explicit step capturing 3 decision types: locked decisions (human chose, agent must honor), deferred ideas (out of scope), Claude's discretion (agent chooses).
**Gap in Shipwright:** Brainstorming is collaborative but doesn't formally categorize decisions. Ambiguity causes drift.
**Priority:** HIGH — eliminates a major source of implementation drift.

### 9. Wave-Based Parallel Execution
**What:** Plans grouped into dependency waves. Within a wave, parallel. Waves are sequential. ~60% parallelism without full DAG complexity.
**Gap in Shipwright:** Planner defines tasks but we haven't specified how parallel execution works within a tier.
**Priority:** HIGH — clean model, simple, effective.

### 10. Plans as Structured Prompts (not prose)
**What:** PLAN.md is exactly what the executor reads — XML/structured format, no intermediate translation. Verification criteria built into each task.
**Gap in Shipwright:** Planner creates task lists but format not defined. Prose tasks → Implementer interprets → drift.
**Priority:** HIGH — structured plans reduce interpretation errors.

### 11. Context Budget Monitoring
**What:** Warns at 85% context usage, critical at 95%. Suggests splitting plans before quality degrades.
**Gap in Shipwright:** We have amnesia recovery but no proactive warning. Only react after compaction.
**Priority:** MEDIUM — proactive is strictly better than reactive. Simple to implement.

### 12. Model Profiles (quality/balanced/budget)
**What:** Switch between opus-heavy and sonnet/haiku-heavy profiles per project. One knob changes all agent model assignments.
**Gap in Shipwright:** We assign models per agent but user can't easily switch cost modes.
**Priority:** MEDIUM — good team UX, easy to implement.

### 13. Gap-Closure Loop
**What:** Verification finds gaps → auto-creates fix plans → execute fixes → re-verify. Structured loop.
**Gap in Shipwright:** QA re-entry cycle is similar but less formalized. GSD's loop is tighter.
**Priority:** MEDIUM — our re-entry cycle covers this conceptually but could be sharpened.

### 14. Brownfield Codebase Analysis
**What:** `map-codebase` spawns 4 agents analyzing tech stack, architecture, conventions, and concerns before any planning.
**Gap in Shipwright:** Triage scans for existing docs but doesn't systematically analyze the codebase itself.
**Priority:** MEDIUM — valuable for teams working on established codebases (most RAI work).

---

## Decisions

### IMPLEMENT NOW (v1)
| # | Idea | Source | Implementation |
|---|------|--------|---------------|
| 7 | Goal-backward verification | GSD | New skill injected into Validator agent |
| 8 | User decision categorization | GSD | New skill injected into Triage/brainstorming (LOCKED/DEFERRED/DISCRETION) |
| 9 | Wave-based parallel execution | GSD | Change to Planner prompt (wave grouping) + orchestrator (parallel wave spawning) |
| 10 | Plans as structured prompts | GSD | Structured task format in Planner prompt (files, action, verify, done-when, wave, deps) |
| 1 | Semantic memory compaction | Beads | Orchestrator compacts decisions.md at phase transitions. Old decisions → digest, details in checkpoints. |
| 11 | Context budget monitoring | GSD | Orchestrator tracks tokens, warns at 85%, forces checkpoint at 95% |
| 14 | Brownfield codebase analysis | GSD | New skill injected into Triage agent |
| 13 | Gap-closure loop | GSD | One-line addition to Planner: on re-entry, read gap list and create targeted fix plans |

### DEFERRED
| # | Idea | Source | Revisit when |
|---|------|--------|-------------|
| 12 | Model profiles | GSD | When cost becomes a team concern |
| 2 | Dependency-aware task graph | Beads | If wave-based execution proves insufficient |
| 3 | Hash-based collision-free IDs | Beads | If we add distributed parallel agents |
| 4 | Deferred tasks with scheduling | Beads | For multi-milestone project support |
| 5 | Inter-agent messaging | Beads | If orchestrator routing becomes a bottleneck |

### CHUCKED
| # | Idea | Source | Reason |
|---|------|--------|--------|
| 6 | Lean context injection | Beads | Quality risk for negligible token savings (~$0.03). CONTEXT.md at 2,500 tokens is already cheap. |

### Updated Totals
- **Skills:** 8 → 11 (added: goal-backward-verification, decision-categorization, brownfield-analysis)
- **Agent prompts:** 11 (unchanged)
- **Orchestrator changes:** +wave execution, +memory compaction, +context budget monitoring, +gap-list re-entry
