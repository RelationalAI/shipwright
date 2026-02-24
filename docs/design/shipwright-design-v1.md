# Shipwright

## An Adaptive Agentic Development Framework

**Date:** 2026-02-23
**Status:** Design complete. 3 open questions punted for team discussion.
**Lineage:** Combines ideas from Superpowers, GSD, and Beads, with RAI-specific requirements layered in.

---

## 1. The Problem

AI coding agents are powerful but undisciplined. They skip design, write code before tests, claim "done" without verifying, and lose all context when the conversation gets long.

Existing frameworks either impose heavy process without enforcing the right disciplines (formal pipelines that still let agents skip tests and claim "done" without evidence) or provide good discipline guides that agents can rationalize their way around (skills with no enforcement mechanism). None solve the context loss problem well. And none provide a clean way to inject org-specific artifacts, templates, and practices — RAI's threat modeling requirements, documentation standards, and observability patterns have no natural home in any existing framework.

## 2. What Shipwright Does

Shipwright is a framework that:

- **Right-sizes process to the task.** A bug fix gets 3 steps. A new feature gets 8. A security-sensitive architecture change gets 15. A Triage agent brainstorms with you to decide which.
- **Enforces engineering discipline.** TDD, design-before-code, and verification-before-completion are hard gates, not suggestions. Agents cannot rationalize their way around them.
- **Survives context loss.** A four-layer recovery system writes state to disk continuously. When the AI's memory gets compacted, it reads its own notes and continues.
- **Produces docs humans actually read.** Documents are written for humans first (concise, decision-focused). AI-detailed supplements are derived separately. A Doc Digest agent walks you through each doc section by section.
- **Tracks costs transparently.** Every agent call is logged with token counts. End-of-session reports show estimated costs using a configurable heuristic — no hidden spend.

**Target audience:** RAI engineering teams.
**Platform:** Claude Code (designed for future portability).
**Distribution:** RAI plugin marketplace (`RelationalAI/claude-plugins`).
**Entry point:** `/shipwright` (single command — auto-detects resume vs. new workflow).

---

## 3. Core Principles

### Ownership
1. Problem domain is fully owned by the human.
2. Solution is jointly owned by human and agent.
3. Execution is owned by the agent.

### Engineering Discipline
4. TDD is iron law. No production code without a failing test first.
5. Verification before completion. Evidence before assertions.
6. Systematic debugging. Root cause before fix (hard gate).
7. Full regression every time. All tiers, every task.
8. Clean PASS/FAIL at every stage. Defined evidence criteria.
9. Goal-backward verification. "Did we achieve the goal?" not just "did tasks complete?"

### Process
10. Right-size ceremony to complexity. Three tiers.
11. Design before code. Hard gate.
12. Feature by feature execution. Bite-sized tasks, manageable PRs.
13. Anti-rationalization. Agents blocked from common shortcuts.
14. Decisions categorized. LOCKED (human chose), DEFERRED (out of scope), DISCRETION (agent chooses).

### Documentation
15. Human-primary docs. AI supplements derived.
16. Docs stay current. Updated before and after every cycle.
17. Decisions captured in repo. Key decisions in committed docs.

### Context and Memory
18. Capture context at every step. Four-layer recovery.
19. Atomic steps. Small, well-defined, independently verifiable.
20. Context trackable across developers. Committed docs carry the story.
21. Semantic compaction. Old decisions summarized at phase transitions.
22. Proactive context monitoring. Warn at 85%, checkpoint at 95%.

### Human in the Loop
23. 2 developers review every requirement, design decision, and PR.
24. Escalation over assumption. One challenge round, then human decides.
25. Human has final say on tier, design, and delivery.

### RAI Awareness
26. Framework is RAI-aware. Infra, coding standards, observability, monitoring.
27. Org-wide standards with per-repo overrides. 3-tier template precedence.
28. Org-wide PR guidance + coding standards.

### Cost and Operations
29. Track and report token usage transparently.
30. Version control discipline. Feature + task branches.
31. Plugin marketplace distribution.

---

## 4. The Tier System

Not every task deserves the same process. Shipwright has three tiers. The Triage agent recommends one; you confirm or override.

### Tier 1 — Quick Fix

For bug fixes, typos, config changes, small tweaks.

```
You describe the bug
  → Triage confirms Tier 1
    → Implementer investigates root cause, writes test, fixes, runs full regression
      → Reviewer validates the fix
        → Done
```

3 agent spawns. No documents generated. Full regression suite still runs. Decision log still records what happened.

### Tier 2 — Standard Feature

For new functionality, meaningful refactors, integrations.

```
You describe the feature
  → Triage recommends Tier 2, analyzes codebase
    → You brainstorm the design together (decisions categorized: LOCKED / DEFERRED / DISCRETION)
      → Doc Writer produces design doc, Doc Digest walks you through it
        → Security Assessor does quick review, updates threat model if needed
          → Planner creates structured tasks grouped into parallel waves
            → Implementers execute in waves (TDD, verification per task)
              → Reviewer gates each task
                → Validator runs regression + goal-backward verification
                  → Doc Writer reconciles all docs
                    → Done
```

~8 steps. Security included. Design doc committed. If validation finds gaps, targeted fix plans are created and re-executed (1 re-entry cycle).

### Tier 3 — Full Ceremony

For architecture changes, new services, security-sensitive or compliance-relevant work.

Same as Tier 2 but adds:
- **Requirements agent** elicits formal requirements with acceptance criteria
- **Researcher, Cost Analyzer, and Security Assessor** run in parallel during requirements
- **Full threat model** (not just quick assessment)
- **Doc Digest walks you through PRD, design doc, AND threat model**
- Up to 3 re-entry cycles if validation finds gaps

~15 steps. Full PRD + design doc + threat model committed.

### What's constant across all tiers

Regardless of tier, every task gets:
- TDD — no production code without a failing test first
- Verification — run it, read it, prove it before claiming done
- Full regression suite — even a typo fix runs all tests
- Goal-backward verification — "did we achieve the goal?" not just "did we complete the tasks?"
- Decision logging — every decision recorded with rationale
- Cost reporting — tokens tracked per step
- Context recovery — state written to disk continuously
- Systematic debugging — root cause before fix, validated by Reviewer

### Mid-workflow tier upgrade

If any agent discovers the task is more complex than the tier allows (e.g., the Security Assessor finds the Tier 2 feature actually needs a full threat model), it recommends upgrading. You decide.

---

## 5. How Agents Work

### The architecture

Agents are **not** persistent processes. They're markdown prompt templates loaded into fresh, ephemeral subagents. The orchestrator spawns a subagent, injects the right prompt ("you are the Security Assessor"), the subagent does its work and dies.

This gives:
- **Clean context** — each agent starts fresh, no pollution from prior tasks
- **Consistent behavior** — same prompt template, same lens, every time
- **Parallelism** — multiple agents can run simultaneously
- **Low maintenance** — change a markdown file, not a codebase

### Naming convention

Action-based, not role-based. No "TechLead" or "PM" — those create friction with actual humans in those roles.

### The roster

**Core agents (all tiers):**

| Agent | What it does |
|-------|-------------|
| **Triage** | Brainstorms with you, recommends tier, analyzes codebase for existing patterns and docs |
| **Implementer** | Writes code + tests using TDD. Runs verification. Self-reviews before submitting. |
| **Reviewer** | Reviews implementation for spec compliance then code quality. Validates root causes during debugging. Can approve, challenge (once), or escalate to you. |
| **Validator** | Runs full regression suite + new tests. Then does goal-backward verification — checks whether the implementation actually achieves the original goal, not just passes tests. Produces gap list if not. |

**Tier 2+ agents:**

| Agent | What it does |
|-------|-------------|
| **Planner** | Breaks design into structured tasks with files, actions, verification criteria, and wave assignments. On re-entry, reads gap list and creates targeted fix plans. |
| **Doc Writer** | Produces human-readable docs using RAI templates. Reconciles planned vs. actual after implementation. Regenerates AI supplements when human docs change. |
| **Doc Digest** | Walks you through documents section by section. Presents, clarifies, or escalates if the doc has quality gaps. |
| **Security Assessor** | Quick OWASP review (Tier 2) or full threat model (Tier 3). Updates existing threat models when changes affect them. |

**Tier 3 only (advisory — cannot block):**

| Agent | What it does |
|-------|-------------|
| **Cost Analyzer** | Estimates dev + operational costs |
| **Researcher** | Explores technical options, prior art, feasibility |
| **Requirements** | Elicits formal requirements, acceptance criteria, non-goals |

### Skills (techniques injected into agents)

Skills are not separate agents. They're documented techniques loaded into an agent's prompt.

| Skill | Injected into | Purpose |
|-------|--------------|---------|
| **TDD** | Implementer | Red-green-refactor cycle. No code before failing test. |
| **Verification** | Implementer, Validator | Must run the command and read the output before claiming success. |
| **Goal-Backward Verification** | Validator | Checks implementation against original goals, not just test results. |
| **Systematic Debugging** | Implementer | 4-phase investigation. Root cause before fix (hard gate). |
| **Anti-rationalization** | All agents | Blocks common shortcuts ("too simple for design", "should work"). |
| **Decision Categorization** | Triage | Categorizes brainstorming decisions as LOCKED, DEFERRED, or DISCRETION. |
| **Brownfield Analysis** | Triage | Analyzes existing codebase: stack, architecture, conventions, concerns. |
| **Threat Modeling** | Security Assessor (Tier 3) | Full threat model process. |
| **Quick Security** | Security Assessor (Tier 2) | OWASP-style review. |
| **Observability** | Implementer | Instrumentation: metrics, logging, tracing per RAI standards. |
| **Monitoring/Alerting** | Planner, Implementer | Alert definitions, dashboards, runbooks. |

**Total: 11 agent prompts + 11 skills + 1 orchestrator**

### The orchestrator

One long-running agent that never does work itself — only routes:
- Reads recovery files on every step (cheap insurance)
- Spawns subagents with the right prompt template
- Collects results, records decisions, updates state
- Tracks token usage from each subagent return
- Compacts old decisions at phase transitions
- Warns at 85% context budget, forces checkpoint at 95%
- Handles recovery after context compaction

### How agents resolve disagreements

```
Agent proposes → Reviewer approves → proceed
Agent proposes → Reviewer challenges → Agent responds → Reviewer approves → proceed
Agent proposes → Reviewer challenges → Agent responds → Still uncertain → ESCALATE TO HUMAN
```

Max one challenge round between agents. Then you decide. Every judgment is recorded in the decision log.

---

## 6. The Document System

### Two layers, one source of truth

Every document has two forms:

| Layer | For | Style |
|-------|-----|-------|
| **Primary** (`*.md`) | Humans | Concise, decision-focused, 2-3 pages max |
| **Supplement** (`*.detail.md`) | AI agents | Schemas, edge cases, test specs, technical detail |

The human doc is the source of truth. The supplement is derived from it. If they conflict, the human doc wins. When the human doc changes, the Doc Writer regenerates the supplement automatically.

### Templates

Three levels of precedence:
1. **Project templates** (in CLAUDE.md or docs/templates/) — highest priority
2. **Org templates** (bundled with the framework) — RAI defaults
3. **Framework defaults** — generic fallback

A project can override org standards when needed. The decision log records which template was used.

### Doc updates happen twice

- **Before implementation:** Planner annotates existing docs with planned changes (lightweight)
- **After implementation:** Doc Writer reconciles what was planned vs. what was built

This gives you spec-first development with accurate final docs.

### Doc Digest — interactive walkthrough

After any document is generated, the Doc Digest agent walks you through it:
- **Presents** each section and asks if it looks right
- **Clarifies** if you ask a question — explains in plain language
- **Escalates** if you're still confused after one clarification — flags it as a doc quality problem

It's not defensive about the doc. If you don't understand it, the doc needs to be better.

### What gets committed

| Path | Git | Why |
|------|-----|-----|
| `docs/**/*.md` | Committed | Human docs — permanent record |
| `docs/**/*.detail.md` | Committed | AI supplements — useful for future agents |
| `.workflow/**` | Gitignored | Session state — ephemeral recovery artifacts |

---

## 7. Surviving Context Loss

The biggest unsolved problem in agentic development: the AI forgets everything when the conversation gets long. Shipwright uses four layers to survive this.

### Layer 1 — State File (where are we?)

`.workflow/state.json` — Machine-readable. ~500 tokens. Updated at every step.

Contains: current tier, phase, step, status, active agent, artifact paths, feature branch, session ID.

### Layer 2 — Decision Log (why are we here?)

`.workflow/decisions.md` — Appended to by every agent that makes a decision.

Each entry is 3-5 lines: what was decided, what the options were, why this choice was made, and whether it's LOCKED, DEFERRED, or DISCRETION.

Key decisions get extracted into committed docs by the Doc Writer. The raw log is gitignored.

**Compaction:** At each phase transition, old decisions are summarized into a digest (~5-10 lines) and the raw entries are archived to the checkpoint. This keeps the log from bloating over long sessions.

### Layer 3 — Checkpoints (save points)

`.workflow/checkpoints/` — Written at each phase transition. ~20-30 lines each.

Self-contained briefings: what was accomplished, key decisions, what docs were updated, what's next. A fresh agent can read one and understand where things stand.

### Layer 4 — Rolling Context (the hot cache)

`.workflow/CONTEXT.md` — The most important file. Capped at 200 lines. **Rewritten** (not appended) to stay current.

Contains: what we're building, current phase, what just happened, what's next, open blockers. Think of it as the note you'd write to yourself if you knew you were about to lose your memory.

### Recovery

**Light recovery (90% of cases):** Read CONTEXT.md + state.json. ~2,500 tokens. Resume.

**Full recovery:** Read all four layers. ~5-7K tokens. Resume with full context.

**Prevention:** The orchestrator tracks cumulative token usage. At 85%, it logs a warning and ensures recovery files are current. At 95%, it forces a full checkpoint write and decision compaction — preparing for likely compaction.

**Trigger:** The orchestrator has a standing rule: "before every subagent spawn, if you're uncertain about the current step, tier, or recent decisions, read your recovery files first." Defensive by default.

---

## 8. Cost Reporting

Every subagent returns total tokens, tool calls, and duration. The orchestrator logs these to `.workflow/usage.json`.

### What you see

**After each phase:**
```
── Build Phase Complete ──────────────────
  Planner (opus)          18,200 tokens   22s
  Implementer x3 (sonnet) 94,000 tokens  186s
  Reviewer x3 (sonnet)    31,500 tokens   48s
  Phase total:            143,700 tokens  256s
  Session total:          218,400 tokens  412s
──────────────────────────────────────────
```

**End of session:**
```
Total tokens: 400,000
By model: opus 320K, sonnet 60K, haiku 20K

Estimated cost (70/30 input/output heuristic):
  opus:   224K in × $15/M + 96K out × $75/M  ≈ $10.56
  sonnet:  42K in × $3/M  + 18K out × $15/M  ≈ $0.40
  haiku:   14K in × $0.25/M + 6K out × $1.25/M ≈ $0.01
                                       Total  ≈ $10.97

* Split estimated via configurable heuristic (default 70/30)
  Adjust in .workflow/config.json → token_split_ratio
```

Total tokens per model are factual. The input/output split and dollar estimate use a transparent, configurable heuristic. No hidden assumptions.

---

## 9. Execution Model

### Structured tasks

The Planner produces tasks in a structured format — not prose. Each task specifies:

```
### Task 3: Create auth middleware

**Files:** src/middleware/auth.ts, src/middleware/auth.test.ts
**Action:**
- Validate JWT from httpOnly cookie using jose library
- Return 401 if invalid
- Attach decoded user to request context if valid

**Verify:**
- `curl -H "Cookie: token=invalid" localhost:3000/api/me` → 401
- `curl -H "Cookie: token=VALID_JWT" localhost:3000/api/me` → 200

**Done when:** Rejects invalid tokens, passes valid tokens with user context.
**Wave:** 2
**Depends on:** Task 1 (user model)
**Decision refs:** D-012 (LOCKED: use JWT), D-015 (DISCRETION: logging library)
```

The Implementer reads this literally. No interpretation, no drift.

### Wave-based parallel execution

Tasks are grouped into waves based on dependencies:

```
Wave 1 (parallel)           Wave 2 (parallel)          Wave 3
┌──────────┐ ┌──────────┐  ┌──────────┐ ┌──────────┐  ┌──────────┐
│ Task 1   │ │ Task 2   │  │ Task 3   │ │ Task 4   │  │ Task 5   │
│ User     │ │ Product  │  │ Orders   │ │ Cart     │  │ Checkout │
│ Model    │ │ Model    │  │ API      │ │ API      │  │ UI       │
└──────────┘ └──────────┘  └──────────┘ └──────────┘  └──────────┘
                                ↑            ↑              ↑
                           needs T1     needs T2       needs T3+T4
```

Within a wave, all tasks run in parallel (separate subagents). Waves run sequentially. GSD claims this achieves ~60% of the benefit of full DAG parallelism — your mileage will vary depending on how interdependent your tasks are, but the complexity reduction is significant.

### Branching

```
main
  └─ feature/rate-limiting              (feature branch)
       ├─ rate-limiting/task-1          (task branch → PR to feature)
       ├─ rate-limiting/task-2          (task branch → PR to feature)
       └─ rate-limiting/task-3          (task branch → PR to feature)
  └─ feature/rate-limiting → PR to main (rollup)
```

Each task gets its own branch. Task branches PR to the feature branch. Feature branch PRs to main.

### Re-entry on failure

If the Validator finds gaps (tests fail OR goal not achieved):
1. Gap list produced with severities
2. Planner reads gap list, creates **targeted** fix plans (not a full re-plan)
3. Fix plans execute
4. Re-validate
5. Repeat up to 1 time (Tier 2) or 3 times (Tier 3)

---

## 10. Plugin Structure

Distributed via the RAI plugin marketplace.

```
plugins/shipwright/
  .claude-plugin/plugin.json
  skills/                        (11 skill files)
  agents/                        (11 agent prompt templates)
  templates/                     (RAI org doc templates)
  commands/
    shipwright.md                (main entry point)
    security-review.md           (standalone assessment)
    security-threat-model.md     (standalone assessment)
    code-review.md               (standalone assessment)
    pr-review.md                 (standalone assessment)
    codebase-analyze.md          (standalone assessment)
```

**Install:**
```bash
/plugin marketplace add https://github.com/RelationalAI/claude-plugins
/plugin install shipwright@rai-claude-plugins
# restart session
/shipwright
```

### Assessment commands (standalone)

Not every use of Shipwright is a build workflow. Sometimes you just want an assessment — no feature, no implementation, no state tracking.

| Command | Agent | Skill | What it does |
|---------|-------|-------|-------------|
| `/shipwright:security-review` | Security Assessor | Quick Security | OWASP-style review of current code |
| `/shipwright:security-threat-model` | Security Assessor | Threat Modeling | Full threat model of the repo |
| `/shipwright:code-review` | Reviewer | — | Review code changes (staged or specified files) |
| `/shipwright:pr-review` | Reviewer | — | Review a specific PR |
| `/shipwright:codebase-analyze` | Triage | Brownfield Analysis | Analyze existing codebase: stack, architecture, conventions, concerns |

These are stateless — no `.workflow/` directory, no recovery layers, no cost tracking. Just the agent prompt + skill, run once, output results.

---

## 11. Open Questions — For Team Discussion

### OQ-1: How should tasks map to PRs?

Branching is decided (task branches → PR to feature → rollup to main). But how do tasks group into PRs?

- **A) One PR per task.** Smallest, most reviewable. More PRs to manage.
- **B) Planner groups related tasks into logical chunks.** Fewer, cohesive PRs. Requires judgment.

### OQ-2: How do we enforce 2-reviewer gates?

- **A) GitHub branch protection.** Require 2 approvals on PRs. For docs, commit to branch and open PR for review.
- **B) Framework-enforced named reviewers.** Orchestrator asks who reviewers are at start, tags both at each gate.
- **C) Both.** GitHub for code PRs, framework for doc reviews.

### OQ-3: How is context handed off between developers?

.workflow/ is gitignored. If dev A starts and dev B picks up, session state is lost.

- **A) Committed docs are the handoff.** Triage reads committed docs, reconstructs context.
- **B) Partially commit .workflow/.** Commit CONTEXT.md and decisions.md. Risk: noisy history.
- **C) Explicit handoff command.** `/shipwright handoff` generates a one-time summary doc.

---

## 12. Decision Log

| # | Decision | Choice | Why |
|---|----------|--------|-----|
| 1 | Approach | ASDLC backbone + Superpowers discipline | Need orchestration + crash recovery + discipline |
| 2 | Target | Internal RAI team tool | Team consistency |
| 3 | Platform | Claude Code, portable later | Markdown skills = portability |
| 4 | Agents | Prompt templates in ephemeral subagents | Clean context + consistent lens |
| 5 | Naming | Action-based (Triage, Implementer) | No human-role friction |
| 6 | Docs | Human-primary, AI-derived | Humans are the audience |
| 7 | Templates | Project > org > framework | Flexible, opinionated defaults |
| 8 | Doc updates | Before and after implementation | Spec-first + accurate finals |
| 9 | Recovery | 4-layer file-based | Survives compaction cheaply |
| 10 | Cost | Total tokens + 70/30 heuristic | Honest, configurable |
| 11 | Root cause | Reviewer validates, 1 challenge, escalate | Fast, human for ambiguity |
| 12 | Security | Tier 2+ (not just Tier 3) | Quick OWASP + threat model updates |
| 13 | Regression | All tiers, every time | Non-negotiable |
| 14 | Distribution | Plugin marketplace | Versioned, namespaced |
| 15 | Tier routing | Triage brainstorms with human | Human has final say |
| 16 | Entry point | `/shipwright` + 5 assessment commands | Auto-detect resume; standalone assessments are stateless |
| 17 | Tier upgrade | Agents recommend, human decides | Adapts to complexity |
| 18 | Decisions | All recorded in log | Audit + recovery |
| 19 | Name | Shipwright | Uncommon, craftsmanship |
| 20 | Monitoring | Separate from observability | Different concerns |
| 21 | Branching | Feature + task branches | Small PRs naturally |
| 22 | PR strategy | PUNTED | Team discussion needed |
| 23 | 2-reviewer | PUNTED | Team discussion needed |
| 24 | Cross-dev handoff | PUNTED | Team discussion needed |
| 25 | Goal verification | Skill in Validator | Catches "tests pass, feature broken" |
| 26 | Decision categories | Skill in Triage | LOCKED/DEFERRED/DISCRETION prevents drift |
| 27 | Parallel execution | Wave-based | ~60% parallelism, low complexity |
| 28 | Task format | Structured (files, action, verify, done-when) | No interpretation drift |
| 29 | Memory compaction | Orchestrator at phase transitions | Prevents decision log bloat |
| 30 | Context monitoring | Warn 85%, checkpoint 95% | Proactive, not reactive |
| 31 | Brownfield analysis | Skill in Triage | Understand codebase before planning |
| 32 | Gap-closure | Planner reads gap list on re-entry | Targeted fixes, not full re-plan |
| 33 | Lean context injection | CHUCKED | Quality risk for $0.03 savings |
| 34 | Model profiles | DEFERRED | Hardcoded is fine for v1 |
| 35 | Typed dependencies | DEFERRED | Waves cover 90% of need |
| 36 | Hash-based IDs | DEFERRED | No collision risk with single orchestrator |
| 37 | Deferred tasks | DEFERRED | Not needed for single-feature workflows |
| 38 | Agent messaging | DEFERRED | Orchestrator routing sufficient |
