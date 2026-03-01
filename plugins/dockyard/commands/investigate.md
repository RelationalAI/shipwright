---
description: Investigate live service issues using observability data (logs, spans, metrics)
argument-hint: [incident key, transaction ID, error description, or service name]
---

# /investigate — Issue Investigation

Stateful two-stage investigation command. Works with any issue: incidents (NCDNTS), bugs, performance complaints, customer-reported problems.

## Setup

Load from the Dockyard plugin root:
1. **Always:** `skills/observability/SKILL.md`

Additional knowledge files loaded in Stage 2 based on classification (see Stage 2 section).

## Entry Points

| Input | Detection | Action |
|---|---|---|
| `NCDNTS-1234` | Matches `[A-Z]+-\d+` | JIRA ticket path |
| `RAI-56789` | Matches `[A-Z]+-\d+` | JIRA ticket path |
| `6f6d1441-...` | Matches UUID | Transaction ID path |
| Free text | No pattern match | Symptom path |
| No arguments | Empty | Ask what to investigate |

### JIRA Ticket Path
1. Read the JIRA ticket using Atlassian MCP (`getJiraIssue`)
2. Read ticket comments (`addCommentToJiraIssue` is write — use read operations only)
3. Read remote issue links (`getJiraIssueRemoteIssueLinks`)
4. Extract anchors from ticket body, comments, and remote links:
   - Transaction IDs (UUIDs)
   - Engine names
   - Account/org aliases
   - Observe dashboard/query links
   - Confluence runbook links (save for Stage 2)
5. Determine time anchor (see Time Anchor Strategy)
6. Proceed to Stage 1

### Transaction ID Path
1. Use the transaction ID as the primary anchor
2. Time anchor: query transaction dataset for timestamp
3. Proceed to Stage 1

### Symptom Path
1. Parse the symptom description for any anchors (account names, service names, time references)
2. If time reference found, parse and convert to UTC
3. If no anchors, ask the user for: what service/account, when it started, what they observed
4. Proceed to Stage 1

## Time Anchor Strategy

Detect whether the incident was system-reported or human-reported:

| Source | Detection | Time Strategy |
|---|---|---|
| System-reported | JIRA reporter is `640a20b693cf25994631a644` or `557058:f58131cb-b67d-43c7-b30d-6b58d40bd077` | Use incident start time from ticket directly |
| Human + transaction ID | Has UUID anchor | Query transaction dataset for actual timestamp |
| Human + time in description | Parseable time string | Parse, convert to UTC (watch for EST/PST/CET) |
| Human + no time info | None of the above | Query recent activity for referenced entity, or ask user |

## Stage 1: Light Triage

Target: resolve 50-80% of issues without deep investigation. Run immediately.

### Parallel Queries (3-4 simultaneous)
Using anchors from the entry point, run in parallel:
1. **Transaction status:** Query transaction + transaction info datasets for the anchor
2. **Error logs:** Dispatch log agent (see Log Agent section)
3. **Active alerts:** Query monitors that fired near the incident time
4. **Span errors:** Query spans dataset for errors related to the anchor

### Classification
Match query results against the triage signals table in SKILL.md. Assign:
- **Classification:** crash / OOM / brownout / pipeline / cross-service / unknown
- **Confidence:** High (clear signals) / Medium (likely but ambiguous) / Low (need deep investigation)

### Triage Card Output

Present the triage card in this exact format:

```
## Triage Card

| Field | |
|-------|---|
| **What** | One-line description of the issue |
| **Who** | Customer (org_alias + account_alias), reporter if from JIRA |
| **Where** | Environment, region, service, engine |
| **Status** | Transaction state, abort reason, current incident status |
| **Classification** | Crash / OOM / brownout / pipeline / cross-service / unknown |
| **Confidence** | High / Medium / Low — with brief justification |
| **Escalation** | Recommended team + Slack channel |
| **Timeline** | Key timestamps: when started, duration, when detected |
| **Observe Links** | Direct links from generate-query-card — use as returned |

### [Classification] Details

(Adaptive section — content varies by classification, see below)
```

**When a field has no data:** show "—" (em dash). Never omit fields.

**Adaptive section by classification:**

| Classification | Adaptive section includes |
|---|---|
| Crash | Termination reason, crash log summary, core dump availability |
| OOM | Termination reason, Jemalloc profile availability, memory metrics |
| Brownout | Heartbeat rate, Julia GC/compilation metrics, thread blocking indicators |
| Pipeline | Pipeline stage affected, batch processing status, stream state |
| Cross-service | SQL-layer timeline, ERP-layer timeline, correlation key used |
| Unknown | Raw signals found (if any), suggested next steps, request for user context |

### After Stage 1

If confidence is High and the issue is clear-cut, Stage 1 may be sufficient. Present the triage card and ask if the user wants deep investigation.

If confidence is Medium or Low, automatically proceed to Stage 2.

## Stage 2: Deep Investigation

Runs as a **background agent** after Stage 1 output is presented. The foreground remains interactive — the user can ask clarifying questions while Stage 2 runs.

### Knowledge File Loading

Load based on Stage 1 classification:

| Classification | Load |
|---|---|
| Crash / OOM / brownout / heartbeat timeout | `knowledge/engine-failures.md` + `knowledge/incident-patterns/engine-incidents.md` |
| Pipeline | `knowledge/data-pipeline.md` + `knowledge/incident-patterns/pipeline-incidents.md` |
| Cross-service | `knowledge/architecture.md` |
| Unknown | `knowledge/incident-patterns/` (all files) — pattern match against symptoms |

**Exception:** If JIRA ticket contained Confluence runbook links, read those via Atlassian MCP (`getConfluencePage`) and use as primary investigation guide INSTEAD of knowledge files.

### Investigation Steps
1. Follow the runbook (ticket-linked Confluence or knowledge file)
2. Run targeted diagnostic queries based on the runbook
3. Check for historical incident patterns (from incident-patterns/ files)
4. Correlate across services if classification suggests cross-service impact

### Deep Investigation Output

Update the triage card header with any new findings (confidence may increase, classification may change).

Add free-form analysis body, ordered by priority:
1. **Root cause** — lead with this if identified
2. **Detailed timeline with evidence**
3. **Impact assessment** — customers, transactions, duration
4. **Correlated data across services**
5. **Related historical incidents** — from incident-patterns files
6. **Recommended actions** — mitigation, escalation, follow-up

## Log Agent

Log analysis is ALWAYS offloaded to a dedicated agent (logs are unbounded context). The main agent never sees raw log lines — only the log agent's summary.

### Stage 1 Log Agent (time-bounded)

Escalation ladder — each step only fires if the previous found no signal:

| Step | Time Window | Severity |
|---|---|---|
| 1 | ±15 min around incident time | error |
| 2 | ±30 min | error |
| 3 | ±15 min | warning |
| 4 | ±30 min | warning |

- Capped at 10 agent turns
- Typical: resolves at step 1 (~20-25s). Full escalation: ~50-60s.
- Returns: key errors found, error patterns, timeline of events

### Stage 2 Log Agent (unconstrained)

Full severity range, wider time windows, thorough reconstruction. No turn cap.

## MCP Degradation

### Atlassian MCP unavailable (can't read JIRA)
- Inform the user: "Can't read the JIRA ticket — Atlassian MCP not configured."
- Direct to setup: https://www.atlassian.com/solutions/ai/mcp
- Offer to investigate with manual input: ask user to paste ticket details

### Observe MCP unavailable (can't query telemetry)
- Follow degradation guidance in SKILL.md

## Rules

- Always show Observe links as returned from `generate-query-card` — do not construct URLs
- Convert nanosecond durations to human-readable
- Limit initial queries to 5 before analyzing (per SKILL.md query workflow)
- Use retry strategies from SKILL.md if queries return no data
- `rel` is deprecated → `lqp`. User-facing: PyRel.
- `maxlevel` is NOT transaction status. Terminal states: COMPLETED (success), ABORTED (failed).
