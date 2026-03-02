# Observability Skill Design

## Problem

Oncall engineers, product developers, and platform/SRE teams need to query telemetry, investigate incidents, and check service health. The raw tooling exists — Observe MCP provides `generate-query-card` and `generate-knowledge-graph-context` for querying datasets, and Atlassian MCP provides access to JIRA incidents and Confluence runbooks. But there is no structured workflow around these tools. The gap is not tooling — it is the structured workflows and domain knowledge that make the tools effective. AI-assisted observability reduces the time and effort required to investigate issues by encoding domain knowledge, automating query patterns, and guiding engineers through proven investigation workflows.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Interaction model | Skill + commands | Skill auto-picked by agents; commands for explicit workflows |
| Skill weight | Medium (~200 lines) | Datasets + keys + tools + triage signals. No runbooks. Context-budget conscious. |
| Skill capabilities | Query, interpret, basic triage, route | Can classify failure types but defers guided investigation to /investigate |
| Commands | `/investigate` + `/observe` | Stateful investigation + stateless operational queries |
| Knowledge files | `knowledge/` directory, topic-organized, command-loadable at runtime | Single source of truth; commands load selectively based on workflow |
| `/observe` scope | Read-only: query + health + monitor status | Write operations deferred until Observe REST API/CLI integration |
| `/investigate` scope | Any issue (incidents, bugs, perf complaints) | Not limited to NCDNTS — works with any JIRA project or direct input |
| Triage model | Two-stage: Light Triage → Deep Investigation | Fast output first; deep investigation in background agent |
| Output format | Fixed header + adaptive body | Builds muscle memory; flexible depth per issue type |

### Alternatives Considered

| Decision | Alternative | Why Rejected |
|----------|-------------|--------------|
| Interaction model | Commands only (no skill) | Agents in orchestrated workflows couldn't access observability without explicit command invocation |
| Interaction model | Skill only (no commands) | Loses explicit entry points for structured workflows |
| Skill weight | Heavy (~300+ lines) | Context window cost too high for agents that only need basic query capability |
| Skill weight | Minimal (~100 lines) | Too thin — agents couldn't classify failure types or route to commands |
| Commands | Single `/observe` command | Blurs stateful/stateless boundary; investigation needs accumulated context, queries don't |
| Commands | Three commands (+ `/health`) | `/health` is stateless like `/observe` — not enough difference to justify a separate command |
| Knowledge files | Organized by source | Commands need knowledge by topic, not by where it came from |
| Knowledge files | Build-time only (baked into commands) | Duplicates knowledge; updating a runbook means updating multiple files |
| `/observe` scope | Read + write | Observe MCP tools are read-only; write support deferred to REST API/CLI |
| Triage model | Single-stage | Too slow for incidents; oncall engineers need actionable output in seconds |

## Degradation and MCP Setup

When MCP tools are unavailable or degraded, commands detect the failure and guide the user.

**Observe MCP unavailable:**
1. Direct user to setup page: `https://171608476159.observeinc.com/settings/mcp` (Claude Code-specific instructions)
2. If user can't access the URL: request whitelisting in `#ext-relationalai-observe` on Slack with a :ticket: emoji

**Observe MCP performance degradation:**
1. Run `/dockyard:feedback` — prompt user to add context (what they queried, what went wrong)
2. Direct user to `#ext-relationalai-observe` for Observe support

**Atlassian MCP unavailable:**
1. Direct user to official setup: https://www.atlassian.com/solutions/ai/mcp

## Skill (SKILL.md)

Auto-picked by agents. ~200 lines max.

**Contains:**
- Compact dataset catalog (name, ID, purpose)
- Lookup keys (rai_transaction_id, rai_engine_name, account_alias, trace_id, etc.)
- Tool instructions (generate-query-card, generate-knowledge-graph-context)
- Query workflow (how to query, retry strategies, result presentation rules)
- Triage signal table (crash/OOM/brownout/pipeline signatures — enough to classify, not investigate)
- Routing guidance (see Routing Heuristic below)

**Does NOT contain:** Runbooks, escalation channels, architecture details, enumerated values, incident patterns.

## `/investigate` — Stateful Issue Investigation

Works for any issue: incidents (NCDNTS), bugs, performance complaints, customer-reported problems.

**Entry points:**
- `/investigate NCDNTS-1234` — reads JIRA, extracts anchors, runs triage
- `/investigate RAI-56789` — works with any JIRA project
- `/investigate <transaction-id>` — direct to transaction investigation
- `/investigate <symptom>` — routes based on described symptoms

### Stage 1: Light Triage

Runs immediately. Produces a structured triage card. Target: resolve 50-80% of issues without needing deep investigation.

1. Parse input (JIRA ticket, transaction ID, or symptom)
2. If JIRA: read ticket + comments + remote links, extract anchors (transaction IDs, engine names, account/org aliases, Observe links, Confluence runbook links)
3. Run 3-4 parallel queries: transaction status, error logs, active alerts, span errors
4. Produce **triage card** (see Output Format)

### Stage 2: Deep Investigation

Runs as a **background agent** after Stage 1 output is presented. Foreground remains interactive for clarifying questions — user answers refine the investigation but don't gate it.

1. **Ticket-linked runbooks take priority.** If JIRA ticket contains Confluence runbook links, read them via Atlassian MCP and use as primary investigation guide.
2. If no ticket-linked runbook, load knowledge file based on classification:
   - Crash / OOM / brownout → `knowledge/engine-failures.md`
   - Data pipeline / CDC → `knowledge/data-pipeline.md`
   - Cross-service → `knowledge/architecture.md`
   - Unknown → `knowledge/incident-patterns/` for pattern matching; ask user for context
3. Follow the runbook (ticket-linked or from knowledge file)
4. Run targeted diagnostic queries
5. Present detailed findings, updating the triage card header + free-form analysis body

## `/observe` — Stateless Operational Queries

**Entry points:**
- `/observe how's prod doing?` — fleet health check
- `/observe error rates for rai-server last 2 hours` — ad-hoc query
- `/observe active alerts` — monitor status
- `/observe` (no args) — asks what you want to check

**Workflow:**
1. Load SKILL.md + `knowledge/platform.md` (always)
2. Load additional knowledge files only when the query explicitly references that domain (e.g., CDC query → also load `data-pipeline.md`)
3. Determine intent: health check, monitor query, or ad-hoc data query
4. Execute queries, present results with Observe links

**Empty/no-result handling:** Distinguish "all clear" (no errors, system healthy) from "no data available" (possible data gap). Zero active alerts = positive signal, not silence.

## Routing Heuristic

The skill uses this rule to route users:

| User intent | Route to |
|-------------|----------|
| Specific incident, failure, error, or JIRA ticket to diagnose | `/investigate` |
| Check current state, fleet health, or run ad-hoc queries | `/observe` |
| Basic observability question (e.g., "what dataset has transaction data?") | Skill handles directly |

## Context Efficiency

The two-stage architecture manages context cost:

| Stage | Context Window | What's Loaded | Cost |
|-------|---------------|---------------|------|
| Skill (auto-picked) | Caller's context | SKILL.md (~200 lines) | Light |
| `/observe` | Main context | SKILL.md + platform.md | Moderate |
| `/investigate` Stage 1 | Main context | SKILL.md + JIRA content + initial queries | Moderate |
| `/investigate` Stage 2 | **Background agent** | Ticket-linked runbook or knowledge file(s) + queries | Heavy (isolated) |

**Key principles:**
- The skill stays lean — loaded into every agent that touches observability
- Stage 2 runs as a background agent with its own context window, isolating the heavy loading from the main conversation
- Stage 2 can split into multiple parallel background agents when triage identifies multiple investigation threads (e.g., engine + CDC issues). Each loads only its relevant knowledge file.
- Query results are summarized, not dumped raw

### Log Agent

Log analysis is always offloaded to a dedicated agent. Log queries are unbounded — the log agent fetches, synthesizes (key errors, patterns, timeline), and returns a compact summary. The main agent never sees raw log lines.

**Stage 1 log agent** is time-bounded with an escalation ladder:

| Step | Scope | Severity |
|------|-------|----------|
| 1 | ±15 min around incident time | error |
| 2 | ±30 min | error |
| 3 | ±15 min | warning |
| 4 | ±30 min | warning |

- Capped at 10 turns. Each step only fires if the previous found no signal.
- Typical: resolves at step 1 (~20-25s). Full escalation: ~50-60s.

**Stage 2 log agent** is not time-bounded — full severity range, wider windows, thorough reconstruction.

### Time Anchor Strategy

Time anchor for log queries depends on incident source. Detect via JIRA reporter field:

| Source | Strategy |
|--------|----------|
| **System-reported** (reporter: `640a20b693cf25994631a644` or `557058:f58131cb-b67d-43c7-b30d-6b58d40bd077`) | Use incident start time from ticket directly |
| **Human-reported with transaction ID** | Query transaction dataset for actual timestamp |
| **Human-reported with time in description** | Parse timestamp, handle timezone conversion |
| **Human-reported, no time info** | Query recent activity for referenced entity, or ask user |

JQL for system-reported: `project = "Incidents (Tier 2 Escalation)" and (reporter = 640a20b693cf25994631a644 or reporter = 557058:f58131cb-b67d-43c7-b30d-6b58d40bd077)`

Be timezone-aware — human-reported incidents may reference local times (EST, PST, CET) needing UTC conversion.

## Output Format

### Triage Card (Stage 1)

Fixed header fields (always present, same order):

| Field | Description |
|-------|-------------|
| **What** | One-line description of the issue |
| **Who** | Customer (org_alias + account_alias), reporter if from JIRA |
| **Where** | Environment, region, service, engine |
| **Status** | Transaction state, abort reason, current incident status |
| **Classification** | Crash / OOM / brownout / pipeline / cross-service / unknown |
| **Confidence** | High (clear signals) / Medium (likely but ambiguous) / Low (need deep investigation) |
| **Escalation** | Recommended team + Slack channel (sourced from knowledge files) |
| **Timeline** | Key timestamps: when it started, duration, when detected |
| **Observe Links** | Direct links from `generate-query-card` response — use as returned |

**When a field has no data:** show "—" (em dash). Consistent field count keeps the card scannable.

**Adaptive section** below the header varies by classification:

| Classification | Adaptive section includes |
|---------------|--------------------------|
| Crash | Termination reason, crash log summary, core dump availability |
| OOM | Termination reason, Jemalloc profile availability, memory metrics |
| Brownout | Heartbeat rate, Julia GC/compilation metrics, thread blocking indicators |
| Pipeline | Pipeline stage affected, batch processing status, stream state |
| Cross-service | SQL-layer timeline, ERP-layer timeline, correlation key used |
| Unknown | Raw signals found (if any), suggested next steps, request for user context |

#### Example

```
## Triage Card

| Field | |
|-------|---|
| **What** | Engine crashed with segmentation fault on customer engine |
| **Who** | western_union (account: wudev_wudatadev) |
| **Where** | spcs-prod, aws_us_west_2, rai-server, engine_wu_prod_1 |
| **Status** | Transaction ABORTED — abort reason: "engine failed" |
| **Classification** | Crash |
| **Confidence** | High — segfault in error logs, termination reason = Failed |
| **Escalation** | Julia team → #team-prod-engine-resource-providers-spcs |
| **Timeline** | Started: 2026-02-28 14:32 UTC, Duration: 3m12s, Detected: 14:35 UTC |
| **Observe Links** | [Engine Failures Dashboard](https://171608476159.observeinc.com/...) |

### Crash Details

- **Termination reason:** Failed
- **Error log:** `segmentation fault at address 0x7f3a2b1c4d00` in Julia runtime
- **Container restarts:** 1 restart detected via spcs.container.restarts.total
- **Affected transactions:** 2 aborted (6f6d1441-..., a3b2c1d0-...)
```

### Deep Investigation Report (Stage 2)

Same fixed header, **updated** with new findings (confidence may increase, classification may change).

Free-form analysis body, ordered by priority:
1. **Root cause** — lead with this if identified
2. **Detailed timeline with evidence**
3. **Impact assessment** — customers, transactions, duration
4. **Correlated data across services**
5. **Related historical incidents** — pattern matching from incident-patterns
6. **Recommended actions** — mitigation, escalation, follow-up

## Knowledge Directory

```
plugins/dockyard/skills/observability/
├── SKILL.md
├── knowledge/
│   ├── platform.md                     # Observe: datasets, dashboards, monitors, query patterns
│   ├── engine-failures.md              # 6 failure patterns, diagnostic signals, escalation
│   ├── data-pipeline.md                # CDC pipeline, process_batches, quarantine, streams
│   ├── architecture.md                 # SPCS architecture, services, environments, telemetry
│   └── incident-patterns/              # Historical incident taxonomy, split by group
│       ├── engine-incidents.md         # Engine crash, OOM, brownout patterns
│       ├── pipeline-incidents.md       # CDC, data stream, telemetry pipeline patterns
│       ├── control-plane-incidents.md  # ERP errors, deployment failures, billing
│       └── infrastructure-incidents.md # Snowflake maintenance, security, CI/CD
```

**Principles:**
- Organized by topic, not by source
- Structured for agent consumption: clear headings, compact tables, lookup-friendly
- Token-efficient: no prose where a table will do
- Self-contained per topic (minor duplication acceptable)
- Incident patterns split into groups for selective loading

**Ownership:** CODEOWNERS. Updated manually until `/knowledge-refresh` ships.

**Loading rules:**
- Skill — never loads knowledge files
- `/investigate` — loads 1-2 files based on classification. Ticket-linked Confluence runbooks take priority.
- `/observe` — always loads `platform.md`. Additional files only when query references that domain.

## Future Enhancements

| Enhancement | Description |
|---|---|
| **JIRA comment posting** | `/investigate` posts triage card and findings as a structured comment on the ticket |
| **Slack context reading** | `/investigate` reads incident Slack threads for context (threads often contain diagnosis before ticket is updated) |
| **Slack findings posting** | Post investigation findings to incident Slack channels |
| **Multi-issue correlation** | Correlate across concurrent alerts — "three alerts fired, are they related?" |
| **Observe write operations** | Create/modify monitors, dashboards, OPAL queries via Observe REST API and CLI |
| **`/knowledge-refresh` command** | Regenerate knowledge files by re-running research agents against Confluence, Observe, and JIRA |
