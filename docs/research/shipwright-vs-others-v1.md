# How Shipwright Compares

A comparison of Shipwright against the four frameworks that influenced its design.

---

## At a Glance

| | Shipwright | ASDLC | Superpowers | GSD | Beads |
|---|-----------|-------|-------------|-----|-------|
| **What it is** | Tiered agent orchestration | Full SDLC state machine | Composable skill library | Phase-based project builder | Graph issue tracker for agents |
| **Approach** | Adaptive ceremony + standalone assessments | Fixed pipeline (21 or 5 steps) | Pick skills that apply | Phase → plan → execute → verify | Ready → claim → work → close |
| **Agents** | 11 prompt templates + 11 skills | 13 specialized agents | Subagents per task (no fixed roles) | 11 specialized agents | No agents (CLI tool) |
| **Who decides process?** | Triage agent + human | User picks /asdlc or /mini-asdlc | Skills auto-trigger by context | User picks commands per phase | User drives CLI |
| **State persistence** | 4-layer recovery | JSON state at 8 checkpoints | None | STATE.md + planning dir | Dolt database (git for SQL) |
| **Docs** | Human-primary + AI supplements | Agent-generated artifacts | Plan files (task lists) | Phase plans (XML-structured) | Issue descriptions |
| **Platform** | Claude Code (portable later) | Claude Code only | Claude Code, Cursor, Codex, OpenCode | Claude Code, OpenCode, Gemini, Codex | Any editor with CLI |
| **Distribution** | Plugin marketplace | Manual install script | Plugin marketplace | npm package | Go binary |
| **Maturity** | Design phase | Internal (RAI) | Open source, battle-tested | Open source, actively used | Open source, 300+ releases |

---

## Shipwright vs. ASDLC

ASDLC is Shipwright's primary structural parent — the orchestration backbone, signal-based gating, and state persistence all come from here.

### What Shipwright keeps from ASDLC
- Pure dispatcher orchestrator (never does work itself)
- Signal-based gating between phases
- Specialized agent lenses (security, cost, research)
- State persistence for crash recovery
- QA → build re-entry loops with bug tracking
- Artifact trail committed to repo

### What Shipwright improves
- **Adaptive ceremony.** ASDLC forces a choice: 21-step full pipeline or 5-step mini. Shipwright has 3 tiers with a Triage agent that helps you pick the right one. You don't have to decide upfront.
- **Agent architecture.** ASDLC has 13 persistent agent definitions (some with 56KB prompts). Shipwright uses prompt templates loaded into ephemeral subagents — lighter, cleaner context, parallelizable.
- **Naming.** ASDLC uses human role names (TechLead, PM, QA). Shipwright uses functional names (Triage, Planner, Reviewer) to avoid friction with actual humans in those roles.
- **Engineering discipline.** ASDLC has a lint agent for format validation. Shipwright has hard-gate skills: TDD, verification-before-completion, systematic debugging, anti-rationalization. These address the real failure modes of agents.
- **Documentation.** ASDLC generates comprehensive agent-focused docs. Shipwright generates human-first docs with AI supplements derived separately, and a Doc Digest agent that walks you through them.
- **Context recovery.** ASDLC persists state at 8 checkpoints. Shipwright adds 3 more layers (decision log, rolling context, checkpoints) and compacts old decisions to prevent bloat.

### What Shipwright loses
- **Lint agent.** ASDLC has a dedicated agent that validates signal format and output structure at each gate. Shipwright relies on the orchestrator and skill-based enforcement instead. This may be less rigorous for format compliance.
- **Exhaustive step definitions.** ASDLC has 24 loop step files with YAML frontmatter defining exact entry/exit criteria, context discovery rules, and stop conditions. Shipwright's agent prompts are less formally specified. This trades rigor for simplicity.

---

## Shipwright vs. Superpowers

Superpowers is Shipwright's discipline parent — TDD, brainstorming hard-gates, and anti-rationalization all come from here.

### What Shipwright keeps from Superpowers
- TDD as iron law
- Brainstorming hard-gate (design before code)
- Anti-rationalization tables
- Verification-before-completion
- Systematic debugging (4-phase investigation)
- Fresh subagent per task (clean context)
- Skills as markdown files (portability)

### What Shipwright improves
- **Orchestration.** Superpowers relies on agent self-discipline to follow the right skills in the right order. Shipwright has a dispatcher orchestrator that enforces sequence.
- **State persistence.** Superpowers has no recovery story. If context gets compacted, you start over. Shipwright has 4-layer recovery.
- **Specialized agents.** Superpowers uses general-purpose subagents for everything. Shipwright has specialized prompt templates (Security Assessor, Cost Analyzer) that bring domain expertise.
- **Cost visibility.** Superpowers doesn't track token usage. Shipwright logs every subagent call and reports costs.
- **Document quality.** Superpowers generates plan files (task lists). Shipwright generates human-readable docs with interactive walkthrough.
- **Tiered process.** Superpowers applies all skills equally regardless of task size. Shipwright right-sizes ceremony.
- **Standalone assessments.** Superpowers skills are standalone by nature. Shipwright's full workflow requires the orchestrator, but also offers 5 standalone assessment commands (`security-review`, `security-threat-model`, `code-review`, `pr-review`, `codebase-analyze`) that run without orchestration — stateless, single-shot.

### What Shipwright loses
- **Cross-platform support.** Superpowers works on Claude Code, Cursor, Codex, and OpenCode today. Shipwright is Claude Code only (with future portability designed in).
- **Simplicity.** Superpowers is 15 markdown files with no orchestrator. You invoke a skill, it guides you. Shipwright has an orchestrator, state files, recovery layers, cost tracking — more surface area for things to go wrong.
- **Community.** Superpowers is open source and battle-tested by many users. Shipwright will be internal to RAI initially.

---

## Shipwright vs. GSD

GSD contributed several ideas to Shipwright during the design review: goal-backward verification, decision categorization, wave-based execution, and structured task formats.

### What Shipwright adopts from GSD
- **Goal-backward verification.** Checking "did we achieve the goal?" not just "did tasks complete?"
- **Decision categorization.** LOCKED / DEFERRED / DISCRETION — eliminating ambiguity about what agents can and can't choose.
- **Wave-based parallel execution.** Group tasks by dependencies into waves, run waves in parallel. GSD claims ~60% of full DAG parallelism benefit — your mileage varies depending on task interdependency.
- **Structured task format.** Tasks specify files, actions, verification, and done-criteria. No prose interpretation.
- **Context budget monitoring.** Warn at 85%, checkpoint at 95%.

### Where Shipwright differs from GSD
- **Team vs. solo.** GSD is designed for a solo developer building a product. Shipwright is for engineering teams with review gates and multi-reviewer requirements.
- **Adaptive vs. fixed process.** GSD has one workflow: discuss → plan → execute → verify. Shipwright has 3 tiers. A bug fix doesn't need the discuss/plan cycle.
- **Agent architecture.** GSD has thin orchestrators with fat agents (200K context per executor). Shipwright has prompt-template agents spawned by a dispatcher.
- **Documentation.** GSD produces .planning/ artifacts (plans, summaries, state). Shipwright produces human-readable docs in docs/ with interactive walkthrough.
- **Security and compliance.** GSD has no security assessment or threat modeling. Shipwright has Security Assessor at Tier 2+ and full threat modeling at Tier 3.

### What Shipwright doesn't adopt from GSD
- **XML task format.** GSD uses XML for precise structure. Shipwright uses structured markdown — more readable for humans, slightly less rigid for machines.
- **Model profiles.** GSD lets you switch between quality/balanced/budget model assignments. Shipwright defers this to v2.
- **.planning/ as sole artifact directory.** GSD puts everything in .planning/. Shipwright separates committed docs (docs/) from session state (.workflow/).

---

## Shipwright vs. Beads

Beads is architecturally very different — it's a CLI tool (not an agent framework) that provides persistent memory for agents. Shipwright adopted one key idea from it.

### What Shipwright adopts from Beads
- **Semantic memory compaction.** Summarizing old decisions into digests at phase transitions to prevent context bloat. Beads does this for issues; Shipwright does it for the decision log.

### Where they solve different problems
- **Beads is infrastructure; Shipwright is process.** Beads provides a graph-based issue tracker that any agent framework can use. Shipwright is an opinionated development workflow. They could theoretically coexist — Shipwright using Beads as its task storage backend.
- **Beads is editor-agnostic.** It's a Go CLI binary that works with any tool. Shipwright is a Claude Code plugin.
- **Beads handles multi-agent coordination natively.** Hash-based IDs, Dolt database with cell-level merge, inter-agent messaging. Shipwright uses a single orchestrator — simpler but less distributed.

### What Shipwright doesn't adopt from Beads
- **Dolt database backend.** Beads uses a version-controlled SQL database. Shipwright uses simple JSON and markdown files. Lower complexity, lower capability.
- **Hash-based collision-free IDs.** Not needed with a single orchestrator. Deferred.
- **Inter-agent messaging.** Orchestrator routing is sufficient for now. Deferred.
- **Deferred tasks with scheduling.** Nice for long-running projects but not needed for single-feature workflows. Deferred.
- **Dependency type system.** Blocks, waits-for, conditional-blocks. Wave-based execution covers most cases. Deferred.

---

## Honest Assessment: Shipwright's Weaknesses

No framework is perfect. Here's where Shipwright is weakest compared to the others:

1. **Unproven.** ASDLC is used at RAI. Superpowers and GSD are open source with real users. Beads has 300+ releases. Shipwright exists only on paper. Many design decisions will need adjustment once real teams use it.

2. **Complexity.** Shipwright has 11 agents, 11 skills, 4 recovery layers, 3 tiers, wave-based execution, cost tracking, decision categorization, and memory compaction. That's a lot of moving parts compared to Superpowers' 15 markdown files. More surface area = more things that can break. The 5 standalone assessment commands offer a lighter entry point, but the full orchestrated workflow is inherently complex.

3. **Claude Code locked (for now).** Superpowers and GSD support multiple platforms. Shipwright is Claude Code only. The markdown-based architecture should make porting straightforward, but it hasn't been done.

4. **No distributed coordination.** Beads handles multiple agents creating tasks concurrently with hash-based IDs and cell-level merge. Shipwright's single-orchestrator model is simpler but won't scale to truly parallel multi-agent workflows.

5. **Human doc quality depends on the Doc Writer.** The human-primary doc philosophy is strong in principle. But if the Doc Writer agent produces poor docs, the Doc Digest walkthrough amplifies the problem rather than fixing it. Template quality becomes critical.

6. **Three punted decisions.** PR strategy, 2-reviewer enforcement, and cross-dev handoff are unresolved. These are team-level concerns that need input beyond one designer.
